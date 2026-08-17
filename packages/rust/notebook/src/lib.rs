#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const NOTEBOOK_SCHEMA_VERSION: &str = "FCF-NOTEBOOK-v1";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Notebook {
    pub schema_version: String,
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub metadata: BTreeMap<String, String>,
    #[serde(default)]
    pub cells: Vec<NotebookCell>,
}

impl Notebook {
    #[must_use]
    pub fn new(id: impl Into<String>, title: impl Into<String>) -> Self {
        Self {
            schema_version: NOTEBOOK_SCHEMA_VERSION.to_owned(),
            id: id.into(),
            title: title.into(),
            metadata: BTreeMap::new(),
            cells: Vec::new(),
        }
    }

    pub fn validate(&self) -> Result<(), NotebookValidationError> {
        if self.schema_version != NOTEBOOK_SCHEMA_VERSION {
            return Err(NotebookValidationError::UnsupportedSchema);
        }
        if self.id.trim().is_empty() {
            return Err(NotebookValidationError::MissingId);
        }
        for cell in &self.cells {
            cell.validate()?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NotebookCell {
    pub id: String,
    pub kind: CellKind,
    pub source: String,
    #[serde(default)]
    pub target: Option<ExecutionTarget>,
    #[serde(default)]
    pub executions: Vec<ExecutionRecord>,
}

impl NotebookCell {
    pub fn validate(&self) -> Result<(), NotebookValidationError> {
        if self.id.trim().is_empty() {
            return Err(NotebookValidationError::MissingCellId);
        }
        match self.kind {
            CellKind::Markdown if self.target.is_some() => {
                Err(NotebookValidationError::MarkdownHasExecutionTarget)
            }
            CellKind::Code | CellKind::Engine | CellKind::Ai if self.target.is_none() => {
                Err(NotebookValidationError::ExecutableCellMissingTarget)
            }
            _ => Ok(()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CellKind {
    Markdown,
    Code,
    Engine,
    Ai,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionTarget {
    pub kind: TargetKind,
    #[serde(default)]
    pub identifier: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TargetKind {
    Python,
    Shell,
    Engine,
    Ai,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionRecord {
    pub id: String,
    pub started_at: String,
    pub finished_at: String,
    pub status: ExecutionStatus,
    pub target: ExecutionTarget,
    #[serde(default)]
    pub stdout: String,
    #[serde(default)]
    pub stderr: String,
    pub provenance: ExecutionProvenance,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ExecutionStatus {
    Succeeded,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionProvenance {
    pub source_digest: String,
    pub working_directory: String,
    pub provider: String,
    #[serde(default)]
    pub command: Vec<String>,
    #[serde(default)]
    pub host_os: String,
    #[serde(default)]
    pub host_arch: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NotebookValidationError {
    UnsupportedSchema,
    MissingId,
    MissingCellId,
    MarkdownHasExecutionTarget,
    ExecutableCellMissingTarget,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_preserves_execution_history() {
        let mut notebook = Notebook::new("nb-1", "ES search");
        notebook.cells.push(NotebookCell {
            id: "cell-1".into(),
            kind: CellKind::Engine,
            source: "verify 4/9658489".into(),
            target: Some(ExecutionTarget {
                kind: TargetKind::Engine,
                identifier: Some("centl".into()),
            }),
            executions: vec![ExecutionRecord {
                id: "run-1".into(),
                started_at: "2026-08-17T00:00:00Z".into(),
                finished_at: "2026-08-17T00:00:01Z".into(),
                status: ExecutionStatus::Succeeded,
                target: ExecutionTarget {
                    kind: TargetKind::Engine,
                    identifier: Some("centl".into()),
                },
                stdout: "verified".into(),
                stderr: String::new(),
                provenance: ExecutionProvenance {
                    source_digest: "sha256:abc".into(),
                    working_directory: ".".into(),
                    provider: "centl".into(),
                    command: vec!["centl".into()],
                    host_os: "macos".into(),
                    host_arch: "arm64".into(),
                },
            }],
        });

        notebook.validate().unwrap();
        let encoded = serde_json::to_string_pretty(&notebook).unwrap();
        let decoded: Notebook = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded, notebook);
    }

    #[test]
    fn markdown_cells_cannot_claim_execution_targets() {
        let cell = NotebookCell {
            id: "cell-1".into(),
            kind: CellKind::Markdown,
            source: "# Notes".into(),
            target: Some(ExecutionTarget {
                kind: TargetKind::Shell,
                identifier: None,
            }),
            executions: vec![],
        };
        assert_eq!(
            cell.validate().unwrap_err(),
            NotebookValidationError::MarkdownHasExecutionTarget
        );
    }
}
