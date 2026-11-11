//! Who wins the race, as a state machine with no I/O, clock or threads (the
//! rules follow pam-race's, by Florian Bernier: github.com/fbernier/pam-race).
//!
//! 1. The first helper to succeed wins.
//! 2. A helper that fails after the user answered its prompt ends the race
//!    with that failure: a wrong password says so at once instead of waiting
//!    on the fingerprint reader.
//! 3. Otherwise the race fails once every helper has failed, with their
//!    common code, or PAM_AUTH_ERR when they differ.
//! 4. A cancelled prompt (^C, EOF, sudo -n) cancels the race.
//! 5. Prompts wait until every helper has said something (or the host gives
//!    up waiting, `settled`), so "Place your finger…" shows before the
//!    password prompt blocks the conversation. Messages go ahead of prompts.
//! 6. Once the user answered a helper, only that helper's messages show.
//! 7. A prompt whose helper is gone is dropped.

use std::collections::VecDeque;

use crate::pam;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Status {
    Running,
    Failed(i32),
}

#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    /// The race is over: return this code.
    Decided(i32),
    /// Show a message (no answer expected).
    Show {
        helper: usize,
        style: i32,
        text: String,
    },
    /// Ask the user; the answer goes back with `answered`.
    Ask {
        helper: usize,
        style: i32,
        text: String,
    },
    /// Nothing to do until a helper says something.
    Wait,
}

pub struct Arbiter {
    helpers: Vec<Status>,
    spoke: Vec<bool>,
    messages: VecDeque<(usize, i32, String)>,
    prompts: VecDeque<(usize, i32, String)>,
    answered: Option<usize>,
    asking: Option<usize>,
    outcome: Option<i32>,
}

fn is_prompt(style: i32) -> bool {
    style == pam::PROMPT_ECHO_OFF || style == pam::PROMPT_ECHO_ON
}

impl Arbiter {
    pub fn new(helpers: usize) -> Self {
        Arbiter {
            helpers: vec![Status::Running; helpers],
            spoke: vec![false; helpers],
            messages: VecDeque::new(),
            prompts: VecDeque::new(),
            answered: None,
            asking: None,
            outcome: if helpers == 0 {
                Some(pam::AUTH_ERR)
            } else {
                None
            },
        }
    }

    pub fn outcome(&self) -> Option<i32> {
        self.outcome
    }

    /// The host is blocked in a prompt that a decided race no longer needs:
    /// it has to be made to return (a newline on its terminal).
    pub fn must_release(&self) -> bool {
        self.outcome.is_some() && self.asking.is_some()
    }

    pub fn message(&mut self, helper: usize, style: i32, text: String) {
        self.spoke[helper] = true;
        if self.outcome.is_some() || self.helpers[helper] != Status::Running {
            return;
        }
        if is_prompt(style) {
            self.prompts.push_back((helper, style, text));
        } else {
            self.messages.push_back((helper, style, text));
        }
    }

    /// A helper finished with `rc`; `None` when it died without saying.
    pub fn done(&mut self, helper: usize, rc: Option<i32>) {
        self.spoke[helper] = true;
        if self.outcome.is_some() || self.helpers[helper] != Status::Running {
            return;
        }
        match rc {
            Some(pam::SUCCESS) => {
                self.outcome = Some(pam::SUCCESS);
                return;
            }
            Some(code) => self.helpers[helper] = Status::Failed(code),
            None => self.helpers[helper] = Status::Failed(pam::AUTH_ERR),
        }
        self.prompts.retain(|(h, _, _)| *h != helper);
        if self.answered == Some(helper) {
            if let Status::Failed(code) = self.helpers[helper] {
                self.outcome = Some(code);
            }
            return;
        }
        let codes: Vec<i32> = self
            .helpers
            .iter()
            .map(|s| match s {
                Status::Failed(c) => Some(*c),
                Status::Running => None,
            })
            .collect::<Option<_>>()
            .unwrap_or_default();
        if !codes.is_empty() {
            let first = codes[0];
            self.outcome = Some(if codes.iter().all(|&c| c == first) {
                first
            } else {
                pam::AUTH_ERR
            });
        }
    }

    /// What the host does next. `settled`: it has waited long enough for
    /// the helpers' first messages.
    pub fn next(&mut self, settled: bool) -> Action {
        if let Some(rc) = self.outcome {
            return Action::Decided(rc);
        }
        while let Some((helper, style, text)) = self.messages.pop_front() {
            if self.answered.is_none() || self.answered == Some(helper) {
                return Action::Show {
                    helper,
                    style,
                    text,
                };
            }
        }
        let everyone_spoke = self.spoke.iter().all(|&s| s);
        if !(settled || everyone_spoke) {
            return Action::Wait;
        }
        while let Some((helper, style, text)) = self.prompts.pop_front() {
            if self.helpers[helper] != Status::Running {
                continue;
            }
            self.asking = Some(helper);
            return Action::Ask {
                helper,
                style,
                text,
            };
        }
        Action::Wait
    }

    /// The host's prompt for `helper` returned with an answer; whether it
    /// still goes to the helper (false once the race was decided meanwhile).
    pub fn answered(&mut self, helper: usize) -> bool {
        self.asking = None;
        if self.outcome.is_some() || self.helpers[helper] != Status::Running {
            return false;
        }
        self.answered = Some(helper);
        true
    }

    /// The host's prompt failed (^C, EOF, sudo -n).
    pub fn cancelled(&mut self) {
        self.asking = None;
        if self.outcome.is_none() {
            self.outcome = Some(pam::CONV_ERR);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FPRINT: usize = 0;
    const PASSWORD: usize = 1;

    fn race() -> Arbiter {
        Arbiter::new(2)
    }

    fn info(text: &str) -> (i32, String) {
        (pam::TEXT_INFO, text.into())
    }

    #[test]
    fn fingerprint_hint_shows_before_the_password_prompt() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        assert_eq!(
            a.next(false),
            Action::Wait,
            "holds the prompt for the reader's hint"
        );
        let (style, text) = info("Place your finger on the fingerprint reader");
        a.message(FPRINT, style, text.clone());
        assert_eq!(
            a.next(false),
            Action::Show {
                helper: FPRINT,
                style,
                text
            }
        );
        assert_eq!(
            a.next(false),
            Action::Ask {
                helper: PASSWORD,
                style: pam::PROMPT_ECHO_OFF,
                text: "Password: ".into()
            }
        );
    }

    #[test]
    fn settling_gives_up_on_a_silent_helper() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        assert_eq!(a.next(false), Action::Wait);
        assert!(matches!(
            a.next(true),
            Action::Ask {
                helper: PASSWORD,
                ..
            }
        ));
    }

    #[test]
    fn finger_while_the_password_prompt_blocks() {
        let mut a = race();
        a.message(FPRINT, pam::TEXT_INFO, "Place your finger".into());
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(false);
        assert!(matches!(a.next(false), Action::Ask { .. }));
        assert!(!a.must_release());
        a.done(FPRINT, Some(pam::SUCCESS));
        assert!(a.must_release(), "the host is in read(): push a newline");
        assert!(!a.answered(PASSWORD), "the half-typed answer is discarded");
        assert!(!a.must_release());
        assert_eq!(a.next(false), Action::Decided(pam::SUCCESS));
    }

    #[test]
    fn right_password_wins() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(true);
        assert!(a.answered(PASSWORD));
        a.done(PASSWORD, Some(pam::SUCCESS));
        assert_eq!(a.next(false), Action::Decided(pam::SUCCESS));
    }

    #[test]
    fn wrong_password_ends_the_race_at_once() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(true);
        assert!(a.answered(PASSWORD));
        a.done(PASSWORD, Some(pam::AUTH_ERR));
        assert_eq!(
            a.next(false),
            Action::Decided(pam::AUTH_ERR),
            "not waiting on the reader"
        );
    }

    #[test]
    fn reader_timing_out_leaves_the_password() {
        let mut a = race();
        a.message(FPRINT, pam::TEXT_INFO, "Place your finger".into());
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(false);
        assert!(matches!(a.next(false), Action::Ask { .. }));
        a.done(FPRINT, Some(pam::SERVICE_ERR));
        assert_eq!(a.outcome(), None, "the password can still win");
        assert!(a.answered(PASSWORD));
        a.done(PASSWORD, Some(pam::SUCCESS));
        assert_eq!(a.next(false), Action::Decided(pam::SUCCESS));
    }

    #[test]
    fn everyone_failing_fails() {
        let mut a = race();
        a.done(FPRINT, Some(pam::AUTH_ERR));
        assert_eq!(a.outcome(), None);
        a.done(PASSWORD, None);
        assert_eq!(a.next(false), Action::Decided(pam::AUTH_ERR));

        let mut b = race();
        b.done(FPRINT, Some(pam::SERVICE_ERR));
        b.done(PASSWORD, Some(pam::SYSTEM_ERR));
        assert_eq!(
            b.next(false),
            Action::Decided(pam::AUTH_ERR),
            "different codes"
        );
    }

    #[test]
    fn cancelling_the_prompt_cancels_the_race() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(true);
        a.cancelled();
        assert_eq!(a.next(false), Action::Decided(pam::CONV_ERR));
    }

    #[test]
    fn after_answering_only_that_helper_speaks() {
        let mut a = race();
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.next(true);
        assert!(a.answered(PASSWORD));
        a.message(FPRINT, pam::ERROR_MSG, "Failed to match fingerprint".into());
        a.message(PASSWORD, pam::ERROR_MSG, "Account expired".into());
        assert_eq!(
            a.next(false),
            Action::Show {
                helper: PASSWORD,
                style: pam::ERROR_MSG,
                text: "Account expired".into()
            }
        );
        assert_eq!(a.next(false), Action::Wait);
    }

    #[test]
    fn a_gone_helpers_prompt_is_dropped() {
        let mut a = race();
        a.message(FPRINT, pam::PROMPT_ECHO_ON, "odd prompt".into());
        a.message(PASSWORD, pam::PROMPT_ECHO_OFF, "Password: ".into());
        a.done(FPRINT, None);
        assert!(matches!(
            a.next(false),
            Action::Ask {
                helper: PASSWORD,
                ..
            }
        ));
    }

    #[test]
    fn nothing_after_the_decision() {
        let mut a = race();
        a.done(FPRINT, Some(pam::SUCCESS));
        a.done(PASSWORD, Some(pam::AUTH_ERR));
        a.message(PASSWORD, pam::TEXT_INFO, "late".into());
        assert_eq!(a.next(false), Action::Decided(pam::SUCCESS));
    }

    #[test]
    fn no_helpers_is_a_failure() {
        assert_eq!(Arbiter::new(0).next(true), Action::Decided(pam::AUTH_ERR));
    }
}
