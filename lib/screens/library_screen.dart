import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Playlists'),
                  selected: true,
                  onSelected: (selected) {},
                ),
                SizedBox(width: 8),
                FilterChip(
                  label: Text('Artists'),
                  selected: false,
                  onSelected: (selected) {},
                ),
                SizedBox(width: 8),
                FilterChip(
                  label: Text('Albums'),
                  selected: false,
                  onSelected: (selected) {},
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.favorite, color: Colors.white),
                  ),
                  title: Text('Liked Songs'),
                  subtitle: Text('50 songs'),
                  trailing: Icon(Icons.more_vert),
                ),
                ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.download, color: Colors.white),
                  ),
                  title: Text('Downloaded'),
                  subtitle: Text('25 songs'),
                  trailing: Icon(Icons.more_vert),
                ),
                ...List.generate(5, (index) {
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        'https://via.placeholder.com/50',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text('My Playlist ${index + 1}'),
                    subtitle: Text('${(index + 1) * 10} songs'),
                    trailing: Icon(Icons.more_vert),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
