import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/models/item.dart';
import 'package:quiz_rpg/providers/player_provider.dart';

class ItemUseButton extends StatelessWidget {
  final IconData iconData;
  final String label;
  final VoidCallback onPressed;
  final ItemType itemType;

  const ItemUseButton({
    super.key,
    required this.iconData,
    required this.label,
    required this.onPressed,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    
    return FutureBuilder<List<Item>>(
      future: playerProvider.getInventoryItems(),
      builder: (context, snapshot) {
        // 아이템 목록 로딩 중
        if (!snapshot.hasData) {
          return _buildButton(context, 0, true);
        }
        
        // 현재 아이템 타입에 해당하는 아이템 개수 계산
        int count = snapshot.data!
            .where((item) => item.type == itemType)
            .length;
        
        return _buildButton(context, count, count <= 0);
      },
    );
  }

  Widget _buildButton(BuildContext context, int count, bool isDisabled) {
    return InkWell(
      onTap: isDisabled ? null : () => _confirmUseItem(context),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 16.0,
        ),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade300
              : Color.fromARGB(
                  (0.2 * 255).round(),
                  Theme.of(context).primaryColor.r.toInt(),
                  Theme.of(context).primaryColor.g.toInt(),
                  Theme.of(context).primaryColor.b.toInt(),
                ),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.shade400
                : Theme.of(context).primaryColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              color: isDisabled
                  ? Colors.grey.shade600
                  : Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(
                color: isDisabled
                    ? Colors.grey.shade600
                    : Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2.0),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: isDisabled
                    ? Colors.grey.shade400
                    : Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                'x$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUseItem(BuildContext context) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // 아이템 사용 확인 다이얼로그
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label 사용'),
        content: Text('$label 아이템을 사용하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('사용'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // 아이템 목록에서 해당 타입의 아이템 ID 찾기
      final items = await playerProvider.getInventoryItems();
      final item = items.firstWhere(
        (item) => item.type == itemType,
        orElse: () => throw Exception('아이템을 찾을 수 없습니다.'),
      );
      
      // 아이템 사용 로직 실행
      bool success = await playerProvider.useItem(item.id);
      if (success) {
        onPressed();
      }
    }
  }
} 