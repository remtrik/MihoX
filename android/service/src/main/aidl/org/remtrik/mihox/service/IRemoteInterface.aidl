package org.remtrik.mihox.service;

import org.remtrik.mihox.service.ICallbackInterface;
import org.remtrik.mihox.service.IEventInterface;
import org.remtrik.mihox.service.IResultInterface;
import org.remtrik.mihox.service.IStateCallback;
import org.remtrik.mihox.service.IVoidInterface;
import org.remtrik.mihox.service.models.NotificationParams;
import org.remtrik.mihox.service.models.VpnOptions;

interface IRemoteInterface {
    void invokeAction(in String data, in ICallbackInterface callback);

    void quickStart(in String initParamsString,
                    in String paramsString,
                    in String stateParamsString,
                    in ICallbackInterface callback,
                    in IVoidInterface onStarted);

    void updateNotificationParams(in NotificationParams params);

    void startService(in VpnOptions options, in long runTime, in IResultInterface result);

    void stopService(in IResultInterface result);

    void setEventListener(in IEventInterface event);

    // Run-state ownership (StateHub): register delivers the current snapshot
    // immediately, then every transition. getServiceState is the pull fallback
    // for consumers that only need a one-shot answer.
    void registerStateCallback(in IStateCallback callback);

    void unregisterStateCallback(in IStateCallback callback);

    String getServiceState();

    void setState(in String state);

    void setCrashlytics(boolean enable);

    void updateDns(in String dns);

    String getAndroidVpnOptions();

    String getCurrentProfileName();

    String getRunTime();

    String getTraffic();

    String getTotalTraffic();

    void startListener();

    void stopListener();
}
