#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperatingSystem {
    MacOS,
    Linux,
    Windows,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CpuArchitecture {
    Arm64,
    X86_64,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HostPlatform {
    pub os: OperatingSystem,
    pub architecture: CpuArchitecture,
}

impl HostPlatform {
    #[must_use]
    pub const fn detect() -> Self {
        Self {
            os: detect_os(),
            architecture: detect_architecture(),
        }
    }

    #[must_use]
    pub const fn is_supported_release_target(self) -> bool {
        matches!(
            (self.os, self.architecture),
            (OperatingSystem::MacOS, CpuArchitecture::Arm64)
                | (OperatingSystem::Linux, CpuArchitecture::Arm64)
                | (OperatingSystem::Linux, CpuArchitecture::X86_64)
                | (OperatingSystem::Windows, CpuArchitecture::X86_64)
        )
    }
}

const fn detect_os() -> OperatingSystem {
    if cfg!(target_os = "macos") {
        OperatingSystem::MacOS
    } else if cfg!(target_os = "linux") {
        OperatingSystem::Linux
    } else if cfg!(target_os = "windows") {
        OperatingSystem::Windows
    } else {
        OperatingSystem::Unknown
    }
}

const fn detect_architecture() -> CpuArchitecture {
    if cfg!(target_arch = "aarch64") {
        CpuArchitecture::Arm64
    } else if cfg!(target_arch = "x86_64") {
        CpuArchitecture::X86_64
    } else {
        CpuArchitecture::Unknown
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn current_ci_host_is_known() {
        let host = HostPlatform::detect();
        assert_ne!(host.os, OperatingSystem::Unknown);
        assert_ne!(host.architecture, CpuArchitecture::Unknown);
    }
}
