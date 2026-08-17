#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const TERMINAL_PROTOCOL_VERSION: &str = "FCF-TERMINAL-v1";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TerminalPlatform {
    Macos,
    Linux,
    Windows,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct TerminalSize {
    pub columns: u16,
    pub rows: u16,
}

impl TerminalSize {
    pub fn validate(self) -> Result<Self, TerminalSpecError> {
        if self.columns < 20 || self.rows < 4 {
            return Err(TerminalSpecError::InvalidSize);
        }
        Ok(self)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TerminalSessionSpec {
    pub protocol_version: String,
    pub id: String,
    pub working_directory: String,
    pub shell: Option<String>,
    pub initial_size: TerminalSize,
    #[serde(default)]
    pub environment: BTreeMap<String, String>,
}

impl TerminalSessionSpec {
    pub fn validate(&self) -> Result<(), TerminalSpecError> {
        if self.protocol_version != TERMINAL_PROTOCOL_VERSION {
            return Err(TerminalSpecError::UnsupportedProtocol);
        }
        if self.id.trim().is_empty() {
            return Err(TerminalSpecError::MissingId);
        }
        self.initial_size.validate()?;
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TerminalLifecycle {
    Created,
    Running,
    Exited,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum TerminalEvent {
    Output { bytes: Vec<u8> },
    Resized { size: TerminalSize },
    Exited { code: Option<i32> },
    Failed { message: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TerminalSpecError {
    UnsupportedProtocol,
    MissingId,
    InvalidSize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_cross_platform_session_spec() {
        let spec = TerminalSessionSpec {
            protocol_version: TERMINAL_PROTOCOL_VERSION.to_owned(),
            id: "term-1".into(),
            working_directory: ".".into(),
            shell: None,
            initial_size: TerminalSize {
                columns: 100,
                rows: 30,
            },
            environment: BTreeMap::new(),
        };
        assert_eq!(spec.validate(), Ok(()));
    }

    #[test]
    fn rejects_unusable_terminal_grid() {
        assert_eq!(
            TerminalSize {
                columns: 10,
                rows: 2
            }
            .validate()
            .unwrap_err(),
            TerminalSpecError::InvalidSize
        );
    }
}
