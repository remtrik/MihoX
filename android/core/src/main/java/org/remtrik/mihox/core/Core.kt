package org.remtrik.mihox.core

import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URL

data object Core {
    private external fun startTun(
        fd: Int,
        cb: TunInterface
    )

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        val colonIndex = address.lastIndexOf(':')
        val host = if (colonIndex != -1) address.substring(0, colonIndex) else address
        val port = if (colonIndex != -1) address.substring(colonIndex + 1).toIntOrNull() ?: 0 else 0

        val cleanHost = if (host.startsWith("[") && host.endsWith("]")) {
            host.substring(1, host.length - 1)
        } else {
            host
        }
        return InetSocketAddress(InetAddress.getByName(cleanHost), port)
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolverProcess: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress, uid: Int) -> String
    ) {
        startTun(fd, object : TunInterface {
            override fun protect(fd: Int) {
                protect(fd)
            }

            override fun resolverProcess(
                protocol: Int,
                source: String,
                target: String,
                uid: Int
            ): String {
                return resolverProcess(
                    protocol,
                    parseInetSocketAddress(source),
                    parseInetSocketAddress(target),
                    uid,
                )
            }
        })
    }

    external fun stopTun()

    init {
        System.loadLibrary("core")
    }
}