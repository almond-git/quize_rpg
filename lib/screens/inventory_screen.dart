import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/models/item.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/services/sound_service.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('인벤토리'),
      ),
      body: FutureBuilder<List<Item>>(
        future: playerProvider.getInventoryItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '보유한 아이템이 없습니다.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          
          final items = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 2,
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getItemColor(item.type),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      _getItemIcon(item.type),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(item.description),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // ignore: unawaited_futures
                      soundService.playSound(SoundType.buttonClick);
                      _useItem(context, playerProvider, item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getItemColor(item.type),
                    ),
                    child: const Text('사용'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getItemColor(ItemType type) {
    switch (type) {
      case ItemType.hintCard:
        return Colors.green;
      case ItemType.timeExtension:
        return Colors.blue;
      case ItemType.expBooster:
        return Colors.purple;
      case ItemType.shield:
        return Colors.orange;
      case ItemType.retryChance:
        return Colors.red;
      case ItemType.topicChange:
        return Colors.teal;
    }
  }

  IconData _getItemIcon(ItemType type) {
    switch (type) {
      case ItemType.hintCard:
        return Icons.lightbulb;
      case ItemType.timeExtension:
        return Icons.access_time;
      case ItemType.expBooster:
        return Icons.trending_up;
      case ItemType.shield:
        return Icons.shield;
      case ItemType.retryChance:
        return Icons.refresh;
      case ItemType.topicChange:
        return Icons.swap_horiz;
    }
  }

  Future<void> _useItem(
    BuildContext context, 
    PlayerProvider playerProvider, 
    Item item
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.name} 사용'),
        content: Text('${item.name}을(를) 지금 사용하시겠습니까?\n\n${item.description}'),
        actions: [
          TextButton(
            onPressed: () {
              // ignore: unawaited_futures
              soundService.playSound(SoundType.buttonClick);
              Navigator.of(context).pop(false);
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // ignore: unawaited_futures
              soundService.playSound(SoundType.buttonClick);
              Navigator.of(context).pop(true);
            },
            child: const Text('사용'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      final success = await playerProvider.useItem(item.id);
      if (success && context.mounted) {
        // ignore: unawaited_futures
        soundService.playSound(SoundType.itemUse);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name}을(를) 사용했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (context.mounted) {
        // ignore: unawaited_futures
        soundService.playSound(SoundType.quizWrong);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('아이템 사용에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 