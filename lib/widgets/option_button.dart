import 'package:flutter/material.dart';
import 'package:quiz_rpg/services/sound_service.dart';

class OptionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isHidden;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.text,
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    this.isHidden = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 힌트를 통해 제거된 옵션은 회색으로 표시
    if (isHidden) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Text(
          '옵션 제거됨',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 색상 설정
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    IconData? leadingIcon;

    if (isCorrect) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      borderColor = Colors.green;
      leadingIcon = Icons.check_circle;
    } else if (isWrong) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      borderColor = Colors.red;
      leadingIcon = Icons.cancel;
    } else if (isSelected) {
      backgroundColor = Theme.of(context).primaryColor.withAlpha(51);
      textColor = Theme.of(context).primaryColor;
      borderColor = Theme.of(context).primaryColor;
      leadingIcon = null;
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.black87;
      borderColor = Colors.grey.shade300;
      leadingIcon = null;
    }

    return InkWell(
      onTap: () {
        // 클릭 효과음 재생 후 콜백 실행
        if (!isHidden && !isCorrect && !isWrong) {
          // ignore: unawaited_futures
          soundService.playSound(SoundType.buttonClick);
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, color: textColor),
              const SizedBox(width: 8.0),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 