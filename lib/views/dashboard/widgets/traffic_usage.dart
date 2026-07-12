import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/app.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  Widget _buildTrafficDataItem(
    BuildContext context,
    Icon icon,
    TrafficValue trafficValue,
  ) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                icon,
                const SizedBox(
                  width: 8,
                ),
                Flexible(
                  flex: 1,
                  child: Text(
                    trafficValue.showValue,
                    style: context.textTheme.bodySmall,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trafficValue.showUnit,
            style: context.textTheme.bodySmall?.toLighter,
          ),
        ],
      );

  Widget _buildLegend(
    BuildContext context,
    Color primaryColor,
    Color secondaryColor,
  ) =>
      LayoutBuilder(
        builder: (_, container) {
          final bodySmall = context.textTheme.bodySmall;
          final uploadText = Text(
            maxLines: 1,
            appLocalizations.upload,
            overflow: TextOverflow.ellipsis,
            style: bodySmall,
          );
          final downloadText = Text(
            maxLines: 1,
            appLocalizations.download,
            overflow: TextOverflow.ellipsis,
            style: bodySmall,
          );
          final uploadTextSize =
              globalState.measure.computeTextSize(uploadText);
          final downloadTextSize =
              globalState.measure.computeTextSize(downloadText);
          final maxTextWidth =
              max(uploadTextSize.width, downloadTextSize.width);
          if (maxTextWidth + 24 > container.maxWidth) {
            return Container();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 8,
                    decoration: ShapeDecoration(
                      color: primaryColor,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  uploadText,
                ],
              ),
              const SizedBox(
                height: 4,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 8,
                    decoration: ShapeDecoration(
                      color: secondaryColor,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  downloadText,
                ],
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        info: Info(
          label: appLocalizations.trafficUsage,
          iconData: Icons.data_saver_off,
        ),
        onPressed: () {},
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(
            top: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Consumer(
                          builder: (_, ref, __) {
                            final totalTraffic =
                                ref.watch(totalTrafficProvider);
                            return DonutChart(
                              data: [
                                DonutChartData(
                                  value: totalTraffic.up.value.toDouble(),
                                  color: primaryColor,
                                ),
                                DonutChartData(
                                  value: totalTraffic.down.value.toDouble(),
                                  color: secondaryColor,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Flexible(
                        child: _buildLegend(
                          context,
                          primaryColor,
                          secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final totalTraffic = ref.watch(totalTrafficProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrafficDataItem(
                        context,
                        Icon(
                          Icons.arrow_upward,
                          color: primaryColor,
                          size: 14,
                        ),
                        totalTraffic.up,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      _buildTrafficDataItem(
                        context,
                        Icon(
                          Icons.arrow_downward,
                          color: secondaryColor,
                          size: 14,
                        ),
                        totalTraffic.down,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}