//! The bits of Linux-PAM both sides use: the module (inside the host's
//! handle) and the helper (which runs a whole service with pam_start).

use std::ffi::{c_char, c_int, c_void};

pub const SUCCESS: c_int = 0;
pub const SERVICE_ERR: c_int = 3;
pub const SYSTEM_ERR: c_int = 4;
pub const AUTH_ERR: c_int = 7;
pub const CONV_ERR: c_int = 19;

pub const ITEM_USER: c_int = 2;
pub const ITEM_TTY: c_int = 3;
pub const ITEM_RHOST: c_int = 4;
pub const ITEM_CONV: c_int = 5;
pub const ITEM_RUSER: c_int = 8;

pub const PROMPT_ECHO_OFF: c_int = 1;
pub const PROMPT_ECHO_ON: c_int = 2;
pub const ERROR_MSG: c_int = 3;
pub const TEXT_INFO: c_int = 4;

#[repr(C)]
pub struct Handle {
    _private: [u8; 0],
}

#[repr(C)]
pub struct Message {
    pub style: c_int,
    pub msg: *const c_char,
}

#[repr(C)]
pub struct Response {
    pub resp: *mut c_char,
    pub retcode: c_int,
}

pub type ConvFn = unsafe extern "C" fn(
    num: c_int,
    msg: *mut *const Message,
    resp: *mut *mut Response,
    appdata: *mut c_void,
) -> c_int;

#[repr(C)]
pub struct Conv {
    pub conv: Option<ConvFn>,
    pub appdata: *mut c_void,
}

#[link(name = "pam")]
extern "C" {
    pub fn pam_get_item(pamh: *const Handle, item: c_int, out: *mut *const c_void) -> c_int;
    pub fn pam_set_item(pamh: *mut Handle, item: c_int, value: *const c_void) -> c_int;
    pub fn pam_get_user(
        pamh: *mut Handle,
        user: *mut *const c_char,
        prompt: *const c_char,
    ) -> c_int;
    pub fn pam_start_confdir(
        service: *const c_char,
        user: *const c_char,
        conv: *const Conv,
        confdir: *const c_char,
        pamh: *mut *mut Handle,
    ) -> c_int;
    pub fn pam_authenticate(pamh: *mut Handle, flags: c_int) -> c_int;
    pub fn pam_end(pamh: *mut Handle, status: c_int) -> c_int;
}
