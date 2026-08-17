#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::path::{Component, Path};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PortablePath(String);

impl PortablePath {
    pub fn new(value: impl Into<String>) -> Result<Self, PortablePathError> {
        let value = value.into();
        let path = Path::new(&value);

        if value.is_empty() {
            return Err(PortablePathError::Empty);
        }
        if path.is_absolute() {
            return Err(PortablePathError::Absolute);
        }
        if path
            .components()
            .any(|component| matches!(component, Component::ParentDir))
        {
            return Err(PortablePathError::EscapesWorkspace);
        }

        Ok(Self(value))
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PortablePathError {
    Empty,
    Absolute,
    EscapesWorkspace,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum WorkspaceObjectKind {
    Source,
    Notebook,
    Document,
    Paper,
    Dataset,
    Experiment,
    Terminal,
    GitDiff,
    GitHubIssue,
    GitHubPullRequest,
    AiSession,
    EngineResult,
    Witness,
    Graph,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkspaceObject {
    pub id: String,
    pub title: String,
    pub kind: WorkspaceObjectKind,
    pub path: Option<PortablePath>,
}

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Workspace {
    pub name: String,
    pub objects: Vec<WorkspaceObject>,
}

impl Workspace {
    #[must_use]
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            objects: Vec::new(),
        }
    }

    pub fn add_object(&mut self, object: WorkspaceObject) {
        self.objects.push(object);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn portable_paths_reject_absolute_paths() {
        #[cfg(unix)]
        assert_eq!(
            PortablePath::new("/tmp/work").unwrap_err(),
            PortablePathError::Absolute
        );
    }

    #[test]
    fn portable_paths_reject_parent_escape() {
        assert_eq!(
            PortablePath::new("experiments/../outside").unwrap_err(),
            PortablePathError::EscapesWorkspace
        );
    }

    #[test]
    fn portable_paths_accept_workspace_relative_paths() {
        let path = PortablePath::new("experiments/es/notebook.fcf").unwrap();
        assert_eq!(path.as_str(), "experiments/es/notebook.fcf");
    }
}
