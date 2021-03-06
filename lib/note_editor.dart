import 'package:flutter/material.dart';
import 'package:journal/note.dart';
import 'package:journal/state_container.dart';
import 'package:journal/widgets/note_header.dart';

class NoteEditor extends StatefulWidget {
  final Note note;

  NoteEditor() : note = null;
  NoteEditor.fromNote(this.note);

  @override
  NoteEditorState createState() {
    if (note == null) {
      return NoteEditorState();
    } else {
      return NoteEditorState.fromNote(note);
    }
  }
}

class NoteEditorState extends State<NoteEditor> {
  Note note = Note();
  final bool newNote;
  TextEditingController _textController = TextEditingController();

  NoteEditorState() : newNote = true {
    note.created = DateTime.now();
  }

  NoteEditorState.fromNote(this.note) : newNote = false {
    _textController = TextEditingController(text: note.body);
  }

  @override
  Widget build(BuildContext context) {
    var bodyWidget = Form(
      child: TextFormField(
        autofocus: true,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        decoration: InputDecoration(
          hintText: 'Write here',
          border: InputBorder.none,
        ),
        controller: _textController,
        textCapitalization: TextCapitalization.sentences,
      ),
    );

    var title = newNote ? "Journal Entry" : "Edit Journal Entry";
    var newJournalScreen = Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: Icon(Icons.check),
          onPressed: () {
            final stateContainer = StateContainer.of(context);
            this.note.body = _textController.text;
            if (this.note.body.isNotEmpty) {
              newNote
                  ? stateContainer.addNote(note)
                  : stateContainer.updateNote(note);
            }
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              if (_noteModified()) {
                showDialog(context: context, builder: _buildAlertDialog);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              NoteHeader(note),
              bodyWidget,
            ],
          ),
        ),
      ),
    );

    return newJournalScreen;
  }

  Widget _buildAlertDialog(BuildContext context) {
    var title = newNote
        ? "Do you want to discard the entry"
        : "Do you want to discard the changes?";

    return AlertDialog(
      // FIXME: Change this to 'Save' vs 'Discard'
      title: Text('Are you sure?'),
      content: Text(title),
      actions: <Widget>[
        FlatButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('No'),
        ),
        FlatButton(
          onPressed: () {
            Navigator.pop(context); // Alert box
            Navigator.pop(context); // Note Editor
          },
          child: Text('Yes'),
        ),
      ],
    );
  }

  bool _noteModified() {
    var noteContent = _textController.text.trim();
    if (noteContent.isEmpty) {
      return false;
    }
    if (note != null) {
      return noteContent != note.body;
    }

    return false;
  }
}
