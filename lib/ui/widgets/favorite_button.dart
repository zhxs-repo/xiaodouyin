import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorite_provider.dart';

class FavoriteButton extends StatelessWidget {
  final String videoPath;
  final int index;

  const FavoriteButton({super.key, required this.videoPath, required this.index});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteProvider>(
      builder: (context, fp, _) {
        final isFav = fp.isFavorite(videoPath);
        return IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
          onPressed: () => fp.toggleFavorite(videoPath, index),
        );
      },
    );
  }
}
