#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EngineCapability {
    ExactArithmetic,
    SymbolicComputation,
    Search,
    Verification,
    NumericalComputation,
    DataProcessing,
    Custom(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ExecutionTransport {
    LocalExecutable,
    RemoteService,
    Container,
    CustomExecutable,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EngineDescriptor {
    pub protocol_version: String,
    pub id: String,
    pub name: String,
    pub repository: Option<String>,
    pub version: Option<String>,
    pub capabilities: Vec<EngineCapability>,
    pub transports: Vec<ExecutionTransport>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EngineRequest {
    pub request_id: String,
    pub operation: String,
    #[serde(default)]
    pub payload: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EngineResponse {
    pub request_id: String,
    pub status: EngineStatus,
    #[serde(default)]
    pub result: Value,
    #[serde(default)]
    pub provenance: Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EngineStatus {
    Ready,
    Running,
    Succeeded,
    Failed,
    Cancelled,
    Unavailable,
}

pub const ENGINE_PROTOCOL_VERSION: &str = "FCF-ENGINE-v1";

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn descriptor_round_trips_as_json() {
        let descriptor = EngineDescriptor {
            protocol_version: ENGINE_PROTOCOL_VERSION.into(),
            id: "centl".into(),
            name: "CENTL".into(),
            repository: Some("chasebryan/centl".into()),
            version: None,
            capabilities: vec![EngineCapability::ExactArithmetic, EngineCapability::Verification],
            transports: vec![ExecutionTransport::LocalExecutable],
        };

        let json = serde_json::to_string(&descriptor).unwrap();
        let decoded: EngineDescriptor = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, descriptor);
    }
}
