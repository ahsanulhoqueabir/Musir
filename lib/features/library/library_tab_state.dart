import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which Library tab is selected (Songs, Albums, Artists, Favorites).
/// Lets Home's quick-access tiles jump to a specific tab.
class LibraryTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final libraryTabProvider = NotifierProvider<LibraryTabNotifier, int>(
  LibraryTabNotifier.new,
);

const libraryTabSongs = 0;
const libraryTabAlbums = 1;
const libraryTabArtists = 2;
const libraryTabFavorites = 3;
