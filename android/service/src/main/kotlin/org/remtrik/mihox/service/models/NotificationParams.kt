package org.remtrik.mihox.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class NotificationParams(
    val title: String = "MihoX",
    val stopText: String = "Stop",
) : Parcelable
