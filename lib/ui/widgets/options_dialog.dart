import 'package:material_ui/material_ui.dart';

class OptionsTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool removeHorizontalPadding;
  final List<String> options;
  final String selectedOption;
  final void Function(String) onSelected;

  const OptionsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    bool? removeHorizontalPadding,
  }) : removeHorizontalPadding = removeHorizontalPadding ?? false;

  @override
  State<OptionsTile> createState() => _OptionsTileState();
}

class _OptionsTileState extends State<OptionsTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(widget.title),
        subtitle: Text(widget.subtitle),
        // remove extra padding
        visualDensity: widget.removeHorizontalPadding
            ? const VisualDensity(horizontal: 0, vertical: -4)
            : null,
        contentPadding: widget.removeHorizontalPadding ? EdgeInsets.zero : null,
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  title: Text(widget.title),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("Cancel"),
                    ),
                  ],
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var option in widget.options)
                        RadioListTile(
                          title: Text(option),
                          value: option,
                          groupValue: widget.selectedOption,
                          onChanged: (value) {
                            widget.onSelected(value!);
                            Navigator.of(context).pop(); // Close the dialog
                          },
                        ),
                    ],
                  ),
                );
              });
        });
  }
}
