//! What the module and a helper say to each other over their SOCK_SEQPACKET
//! socketpair: one packet per message, so no framing and EOF on death.

/// The biggest packet either side sends; an answer longer than this is a
/// conversation error rather than a truncated secret.
pub const MAX_PACKET: usize = 8192;

/// Module -> helper.
#[derive(Debug, PartialEq, Eq)]
pub enum ToHelper {
    /// The service to run and the items to copy into its handle.
    Setup {
        service: String,
        user: String,
        tty: String,
        rhost: String,
        ruser: String,
        confdir: String,
    },
    /// The user's answer to the helper's pending prompt.
    Reply(Vec<u8>),
    /// The prompt was cancelled (^C, EOF, sudo -n): fail the conversation.
    Cancel,
}

/// Helper -> module.
#[derive(Debug, PartialEq, Eq)]
pub enum FromHelper {
    /// A PAM message; `style` is PAM_PROMPT_ECHO_OFF..PAM_TEXT_INFO.
    Message { style: u8, text: String },
    /// pam_authenticate's result.
    Done(i32),
}

fn fields(parts: &[&str]) -> Vec<u8> {
    let mut out = vec![b'S'];
    for (i, p) in parts.iter().enumerate() {
        if i > 0 {
            out.push(0);
        }
        out.extend_from_slice(p.as_bytes());
    }
    out
}

impl ToHelper {
    pub fn encode(&self) -> Vec<u8> {
        match self {
            ToHelper::Setup {
                service,
                user,
                tty,
                rhost,
                ruser,
                confdir,
            } => fields(&[service, user, tty, rhost, ruser, confdir]),
            ToHelper::Reply(answer) => {
                let mut out = vec![b'R'];
                out.extend_from_slice(answer);
                out
            }
            ToHelper::Cancel => vec![b'C'],
        }
    }

    pub fn decode(packet: &[u8]) -> Option<ToHelper> {
        let (&tag, rest) = packet.split_first()?;
        match tag {
            b'S' => {
                let parts: Vec<String> = rest
                    .split(|&b| b == 0)
                    .map(|p| String::from_utf8(p.to_vec()))
                    .collect::<Result<_, _>>()
                    .ok()?;
                let [service, user, tty, rhost, ruser, confdir]: [String; 6] =
                    parts.try_into().ok()?;
                // names that become C strings: no NUL inside, a service and user always
                if service.is_empty() || user.is_empty() {
                    return None;
                }
                Some(ToHelper::Setup {
                    service,
                    user,
                    tty,
                    rhost,
                    ruser,
                    confdir,
                })
            }
            b'R' if !rest.contains(&0) => Some(ToHelper::Reply(rest.to_vec())),
            b'C' if rest.is_empty() => Some(ToHelper::Cancel),
            _ => None,
        }
    }
}

impl FromHelper {
    pub fn encode(&self) -> Vec<u8> {
        match self {
            FromHelper::Message { style, text } => {
                let mut out = vec![b'M', *style];
                out.extend_from_slice(text.as_bytes());
                out
            }
            FromHelper::Done(rc) => {
                let mut out = vec![b'D'];
                out.extend_from_slice(&rc.to_le_bytes());
                out
            }
        }
    }

    pub fn decode(packet: &[u8]) -> Option<FromHelper> {
        let (&tag, rest) = packet.split_first()?;
        match tag {
            b'M' => {
                let (&style, text) = rest.split_first()?;
                if !(1..=4).contains(&style) || text.contains(&0) {
                    return None;
                }
                Some(FromHelper::Message {
                    style,
                    text: String::from_utf8_lossy(text).into_owned(),
                })
            }
            b'D' => Some(FromHelper::Done(i32::from_le_bytes(rest.try_into().ok()?))),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips() {
        let setup = ToHelper::Setup {
            service: "sudo-fprint".into(),
            user: "zbioe".into(),
            tty: "/dev/pts/4".into(),
            rhost: String::new(),
            ruser: "zbioe".into(),
            confdir: String::new(),
        };
        assert_eq!(ToHelper::decode(&setup.encode()), Some(setup));
        let reply = ToHelper::Reply(b"hunter2".to_vec());
        assert_eq!(ToHelper::decode(&reply.encode()), Some(reply));
        assert_eq!(
            ToHelper::decode(&ToHelper::Cancel.encode()),
            Some(ToHelper::Cancel)
        );
        let msg = FromHelper::Message {
            style: 4,
            text: "Place your finger".into(),
        };
        assert_eq!(FromHelper::decode(&msg.encode()), Some(msg));
        assert_eq!(
            FromHelper::decode(&FromHelper::Done(-7).encode()),
            Some(FromHelper::Done(-7))
        );
    }

    #[test]
    fn rejects_malformed() {
        assert_eq!(ToHelper::decode(b""), None);
        assert_eq!(ToHelper::decode(b"S\0zbioe\0\0\0\0"), None); // no service
        assert_eq!(ToHelper::decode(b"Sa\0b\0c"), None); // too few fields
        assert_eq!(ToHelper::decode(b"Rpass\0word"), None); // NUL in an answer
        assert_eq!(ToHelper::decode(b"Cx"), None);
        assert_eq!(FromHelper::decode(b"M\x09text"), None); // unknown style
        assert_eq!(FromHelper::decode(b"D\x01\x02"), None); // short code
        assert_eq!(FromHelper::decode(b"X"), None);
    }
}
