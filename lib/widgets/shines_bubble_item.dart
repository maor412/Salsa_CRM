import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/shines_item_model.dart';

/// Widget לבועת שיינס בודדת
class ShinesBubbleItem extends StatefulWidget {
  final ShinesItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ShinesBubbleItem({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ShinesBubbleItem> createState() => _ShinesBubbleItemState();
}

class _ShinesBubbleItemState extends State<ShinesBubbleItem>
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _toggleActions,
      onTap: () {
        if (_showActions) {
          _toggleActions();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // הבועה הראשית
          Container(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.9),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.item.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // כפתורי פעולה (עריכה ומחיקה)
          if (_showActions)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // כפתור עריכה
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.info,
                      onTap: () {
                        _toggleActions();
                        widget.onEdit();
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // כפתור מחיקה
                    _ActionButton(
                      icon: Icons.delete_rounded,
                      color: AppColors.error,
                      onTap: () {
                        _toggleActions();
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// כפתור פעולה קטן (עריכה/מחיקה)
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
