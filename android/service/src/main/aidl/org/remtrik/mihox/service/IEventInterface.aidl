package org.remtrik.mihox.service;

import org.remtrik.mihox.service.IAckInterface;

interface IEventInterface {
    oneway void onEvent(in String id, in byte[] data, in boolean isSuccess, in IAckInterface ack);
}
