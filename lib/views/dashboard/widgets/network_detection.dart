import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _showDetectionTip() {
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.detectionTip,
      ),
      cancelable: false,
    );
  }

  void _handleForceCheck() {
    final success = detectionState.forceCheck();
    if (!success) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          text: appLocalizations.tooFrequentOperation,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: ValueListenableBuilder<NetworkDetectionState>(
          valueListenable: detectionState.state,
          builder: (_, state, __) {
            final ipInfo = state.ipInfo;
            final isLoading = state.isLoading;
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            final Widget bodyChild;
            if (ipInfo != null) {
              bodyChild = TooltipText(
                text: Text(
                  ipInfo.ip,
                  style: theme.textTheme.bodyMedium?.toLight.adjustSize(1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            } else if (!isLoading) {
              bodyChild = Text(
                "timeout",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.red)
                    .adjustSize(1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            } else {
              bodyChild = const Padding(
                padding: EdgeInsets.all(2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            return CommonCard(
              onPressed: _handleForceCheck,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: globalState.measure.titleMediumHeight + 16,
                    child: Padding(
                      padding: baseInfoEdgeInsets.copyWith(
                        bottom: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          ipInfo != null
                              ? Text(
                                  _countryCodeToEmoji(
                                    ipInfo.countryCode,
                                  ),
                                  style: theme.textTheme.titleMedium?.toLight
                                      .copyWith(
                                    fontFamily: FontFamily.twEmoji.value,
                                  ),
                                )
                              : Icon(
                                  Icons.network_check,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          const SizedBox(
                            width: 8,
                          ),
                          Flexible(
                            flex: 1,
                            child: TooltipText(
                              text: Text(
                                appLocalizations.networkDetection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          AspectRatio(
                            aspectRatio: 1,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: _showDetectionTip,
                              icon: Icon(
                                size: 16.ap,
                                Icons.info_outline,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: baseInfoEdgeInsets.copyWith(
                        top: 0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FadeThroughBox(
                          child: bodyChild,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      );
}