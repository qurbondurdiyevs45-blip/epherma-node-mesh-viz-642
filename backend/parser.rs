use std::collections::HashMap;
use std::sync::Arc;
use regex::Regex;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ErrorSignature {
    pub timestamp: i64,
    pub service_name: String,
    pub severity: String,
    pub message: String,
    pub stack_hash: u64,
    pub language: String,
}

pub struct LogParser {
    patterns: Vec<(LogFormat, Regex)>,
}

#[derive(Debug)]
enum LogFormat {
    Java,
    Python,
    NodeJS,
    Go,
    Rust,
    Generic,
}

impl LogParser {
    pub fn new() -> Self {
        let patterns = vec!(
            (LogFormat::Java, Regex::new(r"(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).*? (?P<sev>ERROR|WARN) .*? - (?P<msg>.*)").unwrap()),
            (LogFormat::Python, Regex::new(r"ERROR:root:(?P<msg>.*)").unwrap()),
            (LogFormat::NodeJS, Regex::new(r"\{.*\"level\":\"error\".*\"message\":\"(?P<msg>[^\"]+)\".*\}").unwrap()),
            (LogFormat::Go, Regex::new(r"level=error\s+msg=(?P<msg>.*)").unwrap()),
            (LogFormat::Rust, Regex::new(r"\[(?P<ts>[^\]]+)\] ERROR (?P<msg>.*)").unwrap()),
        );

        LogParser { patterns }
    }

    pub fn parse_line(&self, line: &str, service_id: &str) -> Option<ErrorSignature> {
        for (format, re) in &self.patterns {
            if let Some(caps) = re.captures(line) {
                let msg = caps.name("msg").map_or("", |m| m.as_str()).to_string();
                let hash = self.generate_hash(&msg);
                
                return Some(ErrorSignature {
                    timestamp: Utc::now().timestamp(),
                    service_name: service_id.to_string(),
                    severity: "ERROR".to_string(),
                    message: msg,
                    stack_hash: hash,
                    language: format!("{:?}", format),
                });
            }
        }
        None
    }

    fn generate_hash(&self, input: &str) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        let mut s = DefaultHasher::new();
        input.hash(&mut s);
        s.finish()
    }
}

pub struct StreamProcessor {
    parser: Arc<LogParser>,
}

impl StreamProcessor {
    pub fn new() -> Self {
        Self {
            parser: Arc::new(LogParser::new()),
        }
    }

    pub async fn process_batch(&self, logs: Vec<String>, service_id: &str) -> Vec<ErrorSignature> {
        let mut signatures = Vec::with_capacity(logs.len());
        
        for line in logs {
            if let Some(sig) = self.parser.parse_line(&line, service_id) {
                signatures.push(sig);
            }
        }
        
        signatures
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_java_parsing() {
        let parser = LogParser::new();
        let log = "2023-10-27 10:00:00 ERROR com.app.Main - NullPointerException at line 42";
        let result = parser.parse_line(log, "auth-service");
        assert!(result.is_some());
        assert_eq!(result.unwrap().language, "Java");
    }

    #[test]
    fn test_rust_parsing() {
        let parser = LogParser::new();
        let log = "[2023-10-27T10:00:00Z] ERROR Connection failed to database";
        let result = parser.parse_line(log, "db-proxy");
        assert!(result.is_some());
        assert_eq!(result.unwrap().language, "Rust");
    }
}