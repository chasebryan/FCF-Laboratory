#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const AI_PROVIDER_PROTOCOL_VERSION: &str = "FCF-AI-v1";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProviderDescriptor {
    pub protocol_version: String,
    pub id: String,
    pub name: String,
    pub supports_interactive_auth: bool,
    pub supports_streaming: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ContextScope {
    Selection,
    File,
    Folder,
    Workspace,
    Notebook,
    Experiment,
    Terminal,
    GitDiff,
    GitHistory,
    GitHubIssue,
    GitHubPullRequest,
    EngineResult,
    Dataset,
    Paper,
    Witness,
    Custom(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextGrant {
    pub scope: ContextScope,
    pub resource_id: String,
    pub one_time: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AiRequest {
    pub request_id: String,
    pub prompt: String,
    #[serde(default)]
    pub context_grants: Vec<ContextGrant>,
    #[serde(default)]
    pub metadata: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AiResponse {
    pub request_id: String,
    pub provider_id: String,
    pub model: Option<String>,
    pub content: String,
    #[serde(default)]
    pub metadata: Value,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn context_grants_are_explicit() {
        let request = AiRequest {
            request_id: "r1".into(),
            prompt: "Review the selected code".into(),
            context_grants: vec![ContextGrant {
                scope: ContextScope::Selection,
                resource_id: "selection:active".into(),
                one_time: true,
            }],
            metadata: Value::Null,
        };

        assert_eq!(request.context_grants.len(), 1);
        assert!(request.context_grants[0].one_time);
    }
}
