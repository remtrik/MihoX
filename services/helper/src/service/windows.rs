use crate::service::hub::run_service;

use std::ffi::OsString;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::runtime::Runtime;
use tokio::sync::oneshot;

use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult},
    service_dispatcher, Result,
};

const SERVICE_NAME: &str = "MihoXHelperService";
const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;

pub fn main() -> Result<()> {
    service_dispatcher::start(SERVICE_NAME, service_entry)
}

define_windows_service!(service_entry, service_main);

pub fn service_main(arguments: Vec<OsString>) {
    let rt = match Runtime::new() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("failed to start Tokio runtime: {e}");
            std::process::exit(1);
        }
    };

    rt.block_on(run_windows_service(arguments));
}

async fn run_windows_service(arguments: Vec<OsString>) {
    if !arguments.is_empty() {
        eprintln!("service arguments (unused): {arguments:?}");
    }

    let (stop_tx, stop_rx) = oneshot::channel::<()>();
    let stop_tx = Arc::new(Mutex::new(Some(stop_tx)));

    let status_handle = match service_control_handler::register(
        SERVICE_NAME,
        move |event| -> ServiceControlHandlerResult {
            match event {
                ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,
                ServiceControl::Stop => {
                    if let Some(tx) = stop_tx.lock().unwrap().take() {
                        let _ = tx.send(());
                    }
                    ServiceControlHandlerResult::NoError
                }
                _ => ServiceControlHandlerResult::NotImplemented,
            }
        },
    ) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("failed to register service control handler: {e}");
            return;
        }
    };

    if let Err(e) = status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Running,
        controls_accepted: ServiceControlAccept::STOP,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    }) {
        eprintln!("failed to set Running status: {e}");
        return;
    }

    tokio::select! {
        result = run_service() => {
            if let Err(e) = result {
                eprintln!("service exited with error: {e}");
            }
        }
        _ = stop_rx => {
            eprintln!("stop signal received");
        }
    }

    let _ = status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Stopped,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    });
}