
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:pet_shop/core/constants/app_constants.dart';

class AccountCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String role;
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const AccountCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  Color _roleColor(String r) =>
      r.toLowerCase() == 'admin' ? Colors.orange : primaryColor;

  String _getLocalizedRole(BuildContext context, String rawRole) {
    final l10n = AppLocalizations.of(context)!;
    return rawRole.toLowerCase() == 'admin' ? l10n.admin : l10n.user;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: secondaryColor,
                    backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.person_outline, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(email,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor(role).withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            role.toLowerCase() == 'admin'
                                ? Icons.security
                                : Icons.person,
                            size: 16,
                            color: _roleColor(role)),
                        const SizedBox(width: 4),
                        Text(_getLocalizedRole(context, role), style: TextStyle(color: _roleColor(role))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}