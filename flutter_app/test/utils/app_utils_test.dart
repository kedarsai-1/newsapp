import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/constants.dart';
import 'package:news_app/utils/app_utils.dart';

void main() {
  group('AppUtils', () {
    test('formatCount abbreviates thousands and millions', () {
      expect(AppUtils.formatCount(999), '999');
      expect(AppUtils.formatCount(1500), '1.5K');
      expect(AppUtils.formatCount(2500000), '2.5M');
    });

    test('validateEmail rejects invalid addresses', () {
      expect(AppUtils.validateEmail(null), isNotNull);
      expect(AppUtils.validateEmail(''), isNotNull);
      expect(AppUtils.validateEmail('not-an-email'), isNotNull);
      expect(AppUtils.validateEmail('user@example.com'), isNull);
    });

    test('validatePassword enforces minimum length', () {
      expect(AppUtils.validatePassword(null), isNotNull);
      expect(AppUtils.validatePassword('1234567'), isNotNull);
      expect(AppUtils.validatePassword('12345678'), isNull);
    });

    test('validateMinLength checks trimmed length', () {
      expect(AppUtils.validateMinLength('  ab  ', 'Title', 5), isNotNull);
      expect(AppUtils.validateMinLength('  hello  ', 'Title', 5), isNull);
    });

    test('statusColor and statusIcon map known statuses', () {
      expect(AppUtils.statusColor('approved'), GlassColors.success);
      expect(AppUtils.statusColor('rejected'), GlassColors.error);
      expect(AppUtils.statusIcon('pending'), Icons.pending);
    });

    test('roleColor and roleIcon map roles', () {
      expect(AppUtils.roleColor('admin'), GlassColors.accentOrangeLight);
      expect(AppUtils.roleIcon('reporter'), Icons.mic);
    });

    test('initials returns one or two letters', () {
      expect(AppUtils.initials('Ada Lovelace'), 'AL');
      expect(AppUtils.initials('Solo'), 'S');
      expect(AppUtils.initials(''), '?');
    });
  });
}
