import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';

class PortField extends StatelessWidget {
  const PortField({
    required this.controller,
    required this.label,
    required this.getOtherPorts,
    required this.onSubmitted,
    this.keyboardType = TextInputType.number,
  });

  final TextEditingController controller;
  final String label;
  final List<String> Function() getOtherPorts;
  final void Function(String) onSubmitted;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
        keyboardType: keyboardType,
        maxLines: 1,
        minLines: 1,
        controller: controller,
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(label);
          }
          final port = int.tryParse(value);
          if (port == null) {
            return appLocalizations.numberTip(label);
          }
          if (port == 0) {
            return null;
          }
          if (port < 1024 || port > 49151) {
            return appLocalizations.portTip(label);
          }
          final otherPorts = getOtherPorts();
          if (otherPorts.contains(value.trim())) {
            return appLocalizations.portConflictTip;
          }
          return null;
        },
      );
}