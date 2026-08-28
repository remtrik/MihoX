package org.remtrik.mihox.service;

import org.remtrik.mihox.service.IAckInterface;

interface ICallbackInterface {
    oneway void onResult(in byte[] data, in boolean isSuccess, in IAckInterface ack);
}