import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/common.dart';
import 'package:mihox/providers/app.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

typedef EditingValueChangeBuilder = Widget Function(CodeLineEditingValue value);
typedef TextEditingValueChangeBuilder = Widget Function(TextEditingValue value);

class YamlIndentationCodeChunkAnalyzer implements CodeChunkAnalyzer {
  const YamlIndentationCodeChunkAnalyzer();

  int _indentOf(String text) {
    if (text.trim().isEmpty) return -1;
    var indent = 0;
    while (indent < text.length && text[indent] == ' ') {
      indent++;
    }
    return indent;
  }

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final indents = [
      for (var i = 0; i < codeLines.length; i++) _indentOf(codeLines[i].text),
    ];

    final chunks = <CodeChunk>[];
    for (var i = 0; i < indents.length; i++) {
      if (indents[i] == -1) continue;

      var next = i + 1;
      while (next < indents.length && indents[next] == -1) {
        next++;
      }
      if (next >= indents.length || indents[next] <= indents[i]) continue;

      var end = i;
      for (var j = next; j < indents.length; j++) {
        if (indents[j] == -1) continue;
        if (indents[j] <= indents[i]) break;
        end = j;
      }
      chunks.add(CodeChunk(i, end));
    }
    return chunks;
  }
}

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    required this.title,
    required this.content,
    this.titleEditable = false,
    this.onSave,
    this.onPop,
    this.supportRemoteDownload = false,
    this.languages = const [
      Language.yaml,
    ],
  });
  final String title;
  final String content;
  final List<Language> languages;
  final bool supportRemoteDownload;
  final bool titleEditable;
  final Function(BuildContext context, String title, String content)? onSave;
  final Future<bool> Function(
      BuildContext context, String title, String content)? onPop;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static final Map<LogicalKeyboardKey, AxisDirection> _arrowKeyDirections = {
    LogicalKeyboardKey.arrowUp: AxisDirection.up,
    LogicalKeyboardKey.arrowDown: AxisDirection.down,
    LogicalKeyboardKey.arrowLeft: AxisDirection.left,
    LogicalKeyboardKey.arrowRight: AxisDirection.right,
  };

  late CodeLineEditingController _controller;
  late CodeFindController _findController;
  late TextEditingController _titleController;
  final _focusNode = FocusNode();

  CodeChunkAnalyzer get _chunkAnalyzer {
    if (widget.languages.contains(Language.yaml) &&
        !widget.languages.contains(Language.javaScript)) {
      return const YamlIndentationCodeChunkAnalyzer();
    }
    return const DefaultCodeChunkAnalyzer();
  }

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.content);
    _findController = CodeFindController(_controller);
    _titleController = TextEditingController(text: widget.title);
    if (system.isDesktop) {
      return;
    }
    _focusNode.onKeyEvent = (_, event) {
      if (!HardwareKeyboard.instance.logicalKeysPressed.contains(
        event.logicalKey,
      )) {
        return KeyEventResult.ignored;
      }
      final direction = _arrowKeyDirections[event.logicalKey];
      if (direction == null) {
        return KeyEventResult.ignored;
      }
      _controller.moveCursor(direction);
      return KeyEventResult.handled;
    };
  }

  @override
  void dispose() {
    _findController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _wrapController(EditingValueChangeBuilder builder) =>
      ValueListenableBuilder(
        valueListenable: _controller,
        builder: (_, value, ___) => builder(value),
      );

  Widget _wrapTitleController(TextEditingValueChangeBuilder builder) =>
      ValueListenableBuilder(
        valueListenable: _titleController,
        builder: (_, value, ___) => builder(value),
      );

  void _handleSearch() {
    _findController.findMode();
  }

  Future<void> _handleImport() async {
    final option = await globalState.showCommonDialog<ImportOption>(
      child: const _ImportOptionsDialog(),
    );
    if (option == null) {
      return;
    }
    if (option == ImportOption.file) {
      final file = await picker.pickerFile();
      if (file == null) {
        return;
      }
      _controller.text = String.fromCharCodes(file.bytes?.toList() ?? []);
      return;
    }
    final url = await globalState.showCommonDialog(
      child: InputDialog(
        title: "导入",
        value: "",
        labelText: appLocalizations.url,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null) {
      return;
    }
    final res = await request.getTextResponseForUrl(url);
    _controller.text = res.data;
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);
    return CommonPopScope(
      onPop: () async {
        if (widget.onPop == null) {
          return true;
        }
        final res = await widget.onPop!(
          context,
          _titleController.text,
          _controller.text,
        );
        return res && context.mounted;
      },
      child: CommonScaffold(
        disableBackground: true,
        appBar: AppBar(
          title: TextField(
            enabled: widget.titleEditable,
            controller: _titleController,
            decoration: InputDecoration(
              border: const _NoInputBorder(),
              hintText: appLocalizations.unnamed,
            ),
            style: context.textTheme.titleLarge,
            autofocus: false,
          ),
          actions: genActions([
            if (widget.onSave != null) _buildSaveButton(),
            if (widget.supportRemoteDownload)
              IconButton(
                onPressed: _handleImport,
                icon: const Icon(Icons.arrow_downward),
              ),
            _buildMoreMenu(),
          ]),
        ),
        body: _buildEditor(isMobileView),
      ),
    );
  }

  Widget _buildSaveButton() => _wrapController(
        (_) => _wrapTitleController(
          (_) => IconButton(
            onPressed: _controller.text != widget.content ||
                    _titleController.text != widget.title
                ? () {
                    widget.onSave!(
                      context,
                      _titleController.text,
                      _controller.text,
                    );
                  }
                : null,
            icon: const Icon(Icons.save_sharp),
          ),
        ),
      );

  Widget _buildMoreMenu() => _wrapController(
        (_) => CommonPopupBox(
          targetBuilder: (open) => IconButton(
            onPressed: () => open(offset: const Offset(-20, 20)),
            icon: const Icon(Icons.more_vert),
          ),
          popup: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                icon: Icons.search,
                label: appLocalizations.search,
                onPressed: _handleSearch,
              ),
              PopupMenuItemData(
                icon: Icons.undo,
                label: appLocalizations.undo,
                onPressed: _controller.canUndo ? _controller.undo : null,
              ),
              PopupMenuItemData(
                icon: Icons.redo,
                label: appLocalizations.redo,
                onPressed: _controller.canRedo ? _controller.redo : null,
              ),
            ],
          ),
        ),
      );

  Widget _buildEditor(bool isMobileView) => CodeEditor(
        findController: _findController,
        findBuilder: (context, controller, readOnly) => FindPanel(
          controller: controller,
          readOnly: readOnly,
          isMobileView: isMobileView,
        ),
        padding: const EdgeInsets.only(right: 16),
        autocompleteSymbols: true,
        focusNode: _focusNode,
        scrollbarBuilder: (context, child, details) => CommonScrollBar(
          controller: details.controller,
          child: child,
        ),
        toolbarController: ContextMenuControllerImpl(),
        chunkAnalyzer: _chunkAnalyzer,
        indicatorBuilder:
            (context, editingController, chunkController, notifier) => Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            DefaultCodeChunkIndicator(
              width: 20,
              controller: chunkController,
              notifier: notifier,
            ),
          ],
        ),
        shortcutsActivatorsBuilder:
            const DefaultCodeShortcutsActivatorsBuilder(),
        controller: _controller,
        style: CodeEditorStyle(
          fontSize: context.textTheme.bodyLarge?.fontSize?.ap,
          fontFamily: FontFamily.jetBrainsMono.value,
          codeTheme: CodeHighlightTheme(
            languages: {
              if (widget.languages.contains(Language.yaml))
                'yaml': CodeHighlightThemeMode(mode: langYaml),
              if (widget.languages.contains(Language.javaScript))
                "javascript": CodeHighlightThemeMode(mode: langJavascript),
            },
            theme: atomOneLightTheme,
          ),
        ),
      );
}

const double _kDefaultFindPanelHeight = 52;

class FindPanel extends StatelessWidget implements PreferredSizeWidget {
  const FindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.isMobileView,
  }) : height = (isMobileView
                ? _kDefaultFindPanelHeight * 2
                : _kDefaultFindPanelHeight) +
            8;
  final CodeFindController controller;
  final bool readOnly;
  final bool isMobileView;
  final double height;

  @override
  Size get preferredSize => Size(
        double.infinity,
        controller.value == null ? 0 : height,
      );

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      color: context.colorScheme.surface,
      alignment: Alignment.centerLeft,
      height: height,
      child: _buildFindInputView(context),
    );
  }

  Widget _buildFindInputView(BuildContext context) {
    final value = controller.value!;
    final result = value.result == null
        ? appLocalizations.none
        : '${value.result!.index + 1}/${value.result!.matches.length}';

    final bar = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isMobileView) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _buildFindInput(context, value),
          ),
          const SizedBox(width: 12),
        ],
        Text(result, style: context.textTheme.bodyMedium),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              _buildIconButton(
                onPressed:
                    value.result == null ? null : controller.previousMatch,
                icon: Icons.arrow_upward,
              ),
              _buildIconButton(
                onPressed: value.result == null ? null : controller.nextMatch,
                icon: Icons.arrow_downward,
              ),
              const SizedBox(width: 2),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: controller.close,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
        ),
      ],
    );

    if (!isMobileView) {
      return bar;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        bar,
        const SizedBox(height: 4),
        _buildFindInput(context, value),
      ],
    );
  }

  Widget _buildFindInput(BuildContext context, CodeFindValue value) => Stack(
        alignment: Alignment.center,
        children: [
          _buildTextField(
            context: context,
            onSubmitted: () {
              if (value.result == null) {
                return;
              }
              controller.nextMatch();
              controller.findInputFocusNode.requestFocus();
            },
            controller: controller.findInputController,
            focusNode: controller.findInputFocusNode,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              _buildCheckText(
                context: context,
                text: 'Aa',
                isSelected: value.option.caseSensitive,
                onPressed: controller.toggleCaseSensitive,
              ),
              _buildCheckText(
                context: context,
                text: '.*',
                isSelected: value.option.regex,
                onPressed: controller.toggleRegex,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      );

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onSubmitted,
  }) =>
      TextField(
        maxLines: 1,
        focusNode: focusNode,
        style: context.textTheme.bodyMedium,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        onSubmitted: (_) => onSubmitted(),
        controller: controller,
      );

  Widget _buildCheckText({
    required BuildContext context,
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final label = Text(text, style: context.textTheme.bodySmall);
    return SizedBox(
      width: 28,
      height: 28,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: isSelected
            ? IconButton.filledTonal(
                onPressed: onPressed,
                padding: const EdgeInsets.all(2),
                icon: label,
              )
            : IconButton(
                onPressed: onPressed,
                padding: const EdgeInsets.all(2),
                icon: label,
              ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) =>
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        style:
            const ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
        icon: Icon(icon, size: 16),
      );
}

class ContextMenuControllerImpl implements SelectionToolbarController {
  OverlayEntry? _overlayEntry;
  bool _isFirstRender = true;

  void _removeOverlayEntry() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isFirstRender = true;
  }

  @override
  void hide(BuildContext context) => _removeOverlayEntry();

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _removeOverlayEntry();
    _overlayEntry = OverlayEntry(
      builder: (context) => CodeEditorTapRegion(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, __, ___) => _buildToolbar(controller, anchors),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildToolbar(
    CodeLineEditingController controller,
    TextSelectionToolbarAnchors anchors,
  ) {
    final hasSelection = controller.selectedText.isNotEmpty;
    final menus = <PopupMenuItemData>[
      if (hasSelection)
        PopupMenuItemData(
            label: appLocalizations.copy, onPressed: controller.copy),
      PopupMenuItemData(
          label: appLocalizations.paste, onPressed: controller.paste),
      if (hasSelection)
        PopupMenuItemData(
            label: appLocalizations.cut, onPressed: controller.cut),
      if (hasSelection && !controller.isAllSelected)
        PopupMenuItemData(
          label: appLocalizations.selectAll,
          onPressed: controller.selectAll,
        ),
    ];

    if (_isFirstRender) {
      _isFirstRender = false;
    } else if (!hasSelection) {
      _removeOverlayEntry();
    }

    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? Offset.zero,
      children: [
        for (var i = 0; i < menus.length; i++)
          TextSelectionToolbarTextButton(
            padding: TextSelectionToolbarTextButton.getPadding(i, menus.length),
            alignment: AlignmentDirectional.centerStart,
            onPressed: menus[i].onPressed == null
                ? null
                : () {
                    menus[i].onPressed!();
                    _removeOverlayEntry();
                  },
            child: Text(menus[i].label),
          ),
      ],
    );
  }
}

class _NoInputBorder extends InputBorder {
  const _NoInputBorder() : super(borderSide: BorderSide.none);

  @override
  _NoInputBorder copyWith({BorderSide? borderSide}) => const _NoInputBorder();

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  _NoInputBorder scale(double t) => const _NoInputBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint,
      {TextDirection? textDirection}) {
    canvas.drawRect(rect, paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {}
}

class _ImportOptionsDialog extends StatefulWidget {
  const _ImportOptionsDialog();

  @override
  State<_ImportOptionsDialog> createState() => _ImportOptionsDialogState();
}

class _ImportOptionsDialogState extends State<_ImportOptionsDialog> {
  void _handleOnTap(ImportOption value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.import,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Wrap(
          children: [
            ListItem(
              onTap: () => _handleOnTap(ImportOption.url),
              title: Text(appLocalizations.importUrl),
            ),
            ListItem(
              onTap: () => _handleOnTap(ImportOption.file),
              title: Text(appLocalizations.importFile),
            ),
          ],
        ),
      );
}
