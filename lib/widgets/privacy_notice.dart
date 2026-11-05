import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';

/// RA 10173 privacy notice shown from the registration form, the sign-in
/// screen and the More tab. Kept in one place so the wording cannot drift.
const String kPrivacyNoticeText =
    'What we collect: your name, birthdate and age, six address fields, email, '
    'username, password (stored only as a one-way scrypt hash), three security '
    'answers (also hashed), your Government ID number (encrypted with AES-256), '
    'move-in date, room type, emergency contact and optional tenancy notes.\n\n'
    'Why we collect it: to identify you as a tenant, place you in a room, '
    'compute rent, contact your emergency contact, and protect the account with '
    'security questions and e-mail codes. The Government ID is required by the '
    'boarding house owner before move-in.\n\n'
    'How it is protected: passwords, security answers and one-time codes are '
    'hashed and cannot be read back. The Government ID is encrypted at rest and '
    'is decrypted only for you and the house owner. Traffic is protected in '
    'transit, sign-in is rate-limited and every security event is logged.\n\n'
    'How long we keep it: while your tenancy is active and for one year after it '
    'ends, then the personal fields are erased. Security logs are kept for one '
    'year.\n\n'
    'Your rights: under the Data Privacy Act of 2012 (RA 10173) you may ask to '
    'see, correct or erase your data, and you may complain to the National '
    'Privacy Commission (privacy.gov.ph).\n\n'
    'Contact: the Tahanan administrator at jamestermulato@gmail.com.';

Future<void> showPrivacyNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      title: Text('Privacy Notice', style: AppType.h3),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Text(
            kPrivacyNoticeText,
            style: AppType.body.copyWith(fontSize: 12.5, height: 1.55),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            'Close',
            style: AppType.bodyStrong.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}
