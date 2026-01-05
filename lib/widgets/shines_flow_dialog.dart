import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/shines_provider.dart';
import '../widgets/shines_bubble_item.dart';
import '../widgets/shines_connector.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_text_field.dart';

/// מודאל תרשים זרימה של שיינסים
class ShinesFlowDialog extends StatefulWidget {
  const ShinesFlowDialog({super.key});

  /// פונקציה לפתיחת המודאל עם אנימציית Hero
  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const ShinesFlowDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ShinesFlowDialog> createState() => _ShinesFlowDialogState();
}

class _ShinesFlowDialogState extends State<ShinesFlowDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addShines() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ShinesProvider>();
    final success = await provider.addShinesItem(text);

    if (success && mounted) {
      _textController.clear();
      _focusNode.unfocus();

      // גלילה אוטומטית לתחתית
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _editShines(String id, String currentText) async {
    final controller = TextEditingController(text: currentText);

    final result = await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'עריכת שיינס',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                label: 'טקסט שיינס',
                hint: 'הזן טקסט חדש',
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ביטול'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('שמור'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );

    if (result != null && result.toString().trim().isNotEmpty && mounted) {
      await context.read<ShinesProvider>().updateShinesItem(id, result.toString());
    }

    controller.dispose();
  }

  Future<void> _deleteShines(String id, String text) async {
    final confirm = await AppDialog.showConfirmDialog(
      context: context,
      title: 'מחיקת שיינס',
      content: 'האם אתה בטוח שברצונך למחוק את השיינס:\n"$text"?',
      confirmText: 'מחק',
      cancelText: 'ביטול',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      await context.read<ShinesProvider>().deleteShinesItem(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Hero(
          tag: 'shinesFab',
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width * 0.9,
              height: size.height * 0.8,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.large,
              ),
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // תרשים הזרימה
                  Expanded(
                    child: _buildFlowChart(),
                  ),

                  // אזור הוספה
                  _buildAddSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: AppRadius.mediumRadius,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'תרשים שיינס',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowChart() {
    return Consumer<ShinesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.items.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'אין עדיין שיינסים',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'הוסף את השיינס הראשון למטה',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              for (int i = 0; i < provider.items.length; i++) ...[
                ShinesBubbleItem(
                  item: provider.items[i],
                  onEdit: () => _editShines(
                    provider.items[i].id,
                    provider.items[i].text,
                  ),
                  onDelete: () => _deleteShines(
                    provider.items[i].id,
                    provider.items[i].text,
                  ),
                ),
                if (i < provider.items.length - 1) const ShinesConnector(),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddSection() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextField(
              controller: _textController,
              focusNode: _focusNode,
              hint: 'הזן שיינס חדש...',
              label: '',
              maxLines: 2,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addShines(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FloatingActionButton(
            onPressed: _addShines,
            backgroundColor: AppColors.primary,
            mini: true,
            heroTag: null,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
