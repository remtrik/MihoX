use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error as IoError, Read};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::{Filter, Reply};

const LISTEN_PORT: u16 = 47890;
const LOG_CAPACITY: usize = 100;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct StartParams {
    pub path: String,
    pub args: Vec<String>,
    pub home_dir: Option<String>,
}

#[derive(Debug, Serialize)]
struct ApiError {
    error: String,
}

struct LogBuffer(VecDeque<String>);

impl LogBuffer {
    fn new() -> Self {
        Self(VecDeque::with_capacity(LOG_CAPACITY))
    }

    fn push(&mut self, message: String) {
        if self.0.len() == LOG_CAPACITY {
            self.0.pop_front();
        }
        self.0.push_back(message);
    }

    fn collect(&self) -> String {
        self.0
            .iter()
            .flat_map(|l| [l.as_str(), "\n"])
            .collect()
    }
}

static LOGS: Lazy<Arc<Mutex<LogBuffer>>> =
    Lazy::new(|| Arc::new(Mutex::new(LogBuffer::new())));

static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn sha256_file(path: &str) -> Result<String, IoError> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 4096];

    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

fn log(message: impl Into<String>) {
    let msg = message.into();
    eprintln!("{msg}");
    LOGS.lock().unwrap().push(msg);
}

fn kill_child() -> bool {
    let mut guard = PROCESS.lock().unwrap();
    if let Some(mut child) = guard.take() {
        if let Err(e) = child.kill() {
            log(format!("kill failed: {e}"));
        }
        let _ = child.wait();
        return true;
    }
    false
}

fn spawn_child(params: &StartParams) -> Result<(), String> {
    let mut command = Command::new(&params.path);
    command.args(&params.args).stderr(Stdio::piped());

    if let Some(home_dir) = &params.home_dir {
        command.env("SAFE_PATHS", home_dir);
    }

    let mut child = command.spawn().map_err(|e| {
        log(format!("spawn error: {e}"));
        e.to_string()
    })?;

    let stderr = child.stderr.take().expect("stderr was piped");
    thread::spawn(move || {
        for line in io::BufReader::new(stderr).lines() {
            match line {
                Ok(l) => log(l),
                Err(_) => break,
            }
        }
    });

    *PROCESS.lock().unwrap() = Some(child);
    Ok(())
}

fn handle_start(params: StartParams) -> impl Reply {
    let hash = match sha256_file(&params.path) {
        Ok(h) => h,
        Err(e) => {
            let msg = format!("cannot read '{}': {e}", params.path);
            log(&msg);
            return warp::reply::with_status(
                msg,
                warp::http::StatusCode::BAD_REQUEST,
            );
        }
    };

    if hash != env!("TOKEN") {
        let msg = format!(
            "SHA256 mismatch — got {hash}, expected {}",
            env!("TOKEN")
        );
        log(&msg);
        return warp::reply::with_status(
            msg,
            warp::http::StatusCode::FORBIDDEN,
        );
    }

    kill_child();

    match spawn_child(&params) {
        Ok(()) => warp::reply::with_status(
            String::new(),
            warp::http::StatusCode::OK,
        ),
        Err(e) => warp::reply::with_status(
            e,
            warp::http::StatusCode::INTERNAL_SERVER_ERROR,
        ),
    }
}

fn handle_stop() -> impl Reply {
    kill_child();
    warp::reply::with_status(String::new(), warp::http::StatusCode::OK)
}

fn handle_logs() -> impl Reply {
    let body = LOGS.lock().unwrap().collect();
    warp::reply::with_header(body, "Content-Type", "text/plain; charset=utf-8")
}

pub async fn run_service() -> anyhow::Result<()> {
    let ping = warp::get()
        .and(warp::path("ping"))
        .map(|| env!("TOKEN"));

    let start = warp::post()
        .and(warp::path("start"))
        .and(warp::body::content_length_limit(64 * 1024))
        .and(warp::body::json())
        .map(handle_start);

    let stop = warp::post()
        .and(warp::path("stop"))
        .map(handle_stop);

    let logs = warp::get()
        .and(warp::path("logs"))
        .map(handle_logs);

    let routes = ping.or(start).or(stop).or(logs);

    warp::serve(routes)
        .run(([127, 0, 0, 1], LISTEN_PORT))
        .await;

    Ok(())
}