import 'package:material_ui/material_ui.dart';

import '/ui/widgets/alert_dialog.dart';
import '/utils/global_vars.dart';

class FakeRemindersScreen extends StatefulWidget {
  final Function parentStopConcealing;

  const FakeRemindersScreen({super.key, required this.parentStopConcealing});

  @override
  State<FakeRemindersScreen> createState() => _FakeRemindersScreenState();
}

class _FakeRemindersScreenState extends State<FakeRemindersScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>?>(
        future: sharedStorage.getStringList("appearance_fake_reminders_list"),
        builder: (context, snapshot) {
          // Don't show anything until the future is done
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          return Scaffold(
            appBar: AppBar(
              title: Text("Reminders",
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            body: ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    tileColor: Theme.of(context).colorScheme.surfaceVariant,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    title: Text(snapshot.data![index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          setState(() => snapshot.data!.removeAt(index)),
                    ),
                  )),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ThemedDialog(
                        title: "Add Reminder",
                        content: TextField(
                          controller: _controller,
                          decoration:
                              const InputDecoration(hintText: "Enter reminder"),
                        ),
                        primaryText: "Add",
                        onPrimary: () async {
                          if (_controller.text.trim().toLowerCase() ==
                              "stop concealing") {
                            logger.i("Unconcealing app");
                            widget.parentStopConcealing();
                            Navigator.pop(context); // Close the dialog
                            return;
                          }
                          if (_controller.text.isNotEmpty) {
                            snapshot.data!.add(_controller.text);
                            await sharedStorage.setStringList(
                                "appearance_fake_reminders_list",
                                snapshot.data!);
                            setState(() {});
                            _controller.clear(); // Clear the text field
                            Navigator.pop(context); // Close the dialog
                          }
                        },
                        secondaryText: "Cancel",
                        onSecondary: () => Navigator.pop(context));
                  },
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}
