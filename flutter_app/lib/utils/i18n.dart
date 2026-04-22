import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';

/// Lightweight (non-ARB) i18n for a few UI labels.
/// Uses the feed language preference as the app language.
class I18n {
  static String lang(BuildContext context) =>
      context.read<NewsProvider>().selectedLanguage;

  static String t(BuildContext context, String key) {
    final l = lang(context);
    final map = _strings[l] ?? _strings['en']!;
    return map[key] ?? _strings['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'tab_feed': 'Feed',
      'tab_saved': 'Saved',
      'tab_settings': 'Settings',
      'tab_home': 'Home',
      'tab_my_posts': 'My Posts',
      'tab_dashboard': 'Dashboard',
      'tab_pending': 'Pending',
      'tab_users': 'Users',
      'settings_title': 'Settings',
      'signin_access_settings': 'Sign in to access settings',
      'action_signin': 'Sign In',
      'section_account': 'Account',
      'section_appearance': 'Appearance',
      'section_app': 'App',
      'section_account_status': 'Account Status',
      'tile_edit_profile': 'Edit Profile',
      'tile_change_password': 'Change Password',
      'tile_notification_prefs': 'Notification Preferences',
      'tile_become_reporter': 'Become a Reporter',
      'become_reporter_msg':
          'Reporter registration requires creating a Reporter account. We’ll sign you out and take you to the Reporter sign-up screen.',
      'tile_privacy_policy': 'Privacy Policy',
      'tile_about': 'About NewsNow',
      'tile_help_support': 'Help & Support',
      'tile_clear_cache': 'Clear cache',
      'tile_clear_cache_sub': 'Images and local temporary files',
      'action_signout': 'Sign Out',
      'confirm_signout_title': 'Sign Out',
      'confirm_signout_msg': 'Are you sure you want to sign out?',
      'confirm_clear_cache_title': 'Clear cache',
      'confirm_clear_cache_msg':
          'This will clear image cache and local temporary files. You may need to reload some images.',
      'confirm_continue': 'Continue',
      'snack_cache_cleared': 'Cache cleared',
      'privacy_title': 'Privacy Policy',
      'privacy_last_updated': 'Last updated: Apr 22, 2026',
      'privacy_placeholder':
          'This is a placeholder privacy policy for NewsNow. Replace this content with your real policy before production.',
      'privacy_collect_title': 'What we collect',
      'privacy_collect_body':
          '- Account info (name, email/phone)\n- Usage analytics (optional)\n- Device tokens for notifications (if enabled)',
      'privacy_use_title': 'How we use it',
      'privacy_use_body':
          'To provide the news feed, authenticate users, send notifications, and improve app reliability.',
      'privacy_contact_title': 'Contact',
      'privacy_contact_body': 'If you have questions, contact the app administrator.',

      // Auth - Register
      'reg_title': 'Create account',
      'reg_subtitle': 'Join NewsNow — fill in your details',
      'reg_have_account': 'Already have an account? ',
      'action_create_account': 'Create Account',
      'field_full_name': 'Full Name',
      'hint_full_name': 'e.g. Ravi Kumar',
      'field_email': 'Email Address',
      'hint_email': 'you@example.com',
      'field_phone': 'Phone Number',
      'hint_phone_optional': '+91 98765 43210 (optional)',
      'field_password': 'Password',
      'hint_password': 'Min 6 chars, letters + numbers',
      'field_confirm_password': 'Confirm Password',
      'hint_confirm_password': 'Re-enter your password',

      // Auth - Login
      'login_subtitle': 'Sign in to your account',
      'login_admin_note': 'Admins must use password login. Reporters and users can use either method.',
      'login_hint_password': 'Enter your password',
      'login_otp_note': 'A 6-digit OTP will be sent to your registered email or phone number.',
      'login_field_target': 'Email or Phone Number',
      'login_hint_target': 'you@example.com  or  +91 98765 43210',
      'login_send_otp': 'Send OTP',
      'login_change_target': 'Change number / email',
      'login_code_sent_to': 'Code sent to',
      'login_verify_signin': 'Verify & Sign In',
      'login_code_expires': 'Code expires in 10 minutes',

      // Validation errors
      'err_email_required': 'Email is required',
      'err_email_invalid': 'Enter a valid email address',
      'err_password_required': 'Password is required',
      'err_password_min': 'Minimum 6 characters',
      'err_target_required': 'Email or phone number is required',
      'err_target_invalid': 'Enter a valid email or phone number',

      // Register validation + API errors
      'err_name_required': 'Full name is required',
      'err_name_min': 'At least 2 characters required',
      'err_name_max': 'Must not exceed 60 characters',
      'err_name_invalid': 'Enter a valid name',
      'err_phone_invalid': 'Enter a valid mobile number',
      'err_password_letter': 'Must contain at least one letter',
      'err_password_number': 'Must contain at least one number',
      'err_confirm_required': 'Please confirm your password',
      'err_confirm_mismatch': 'Passwords do not match',
      'err_reg_email_required': 'Email is required for registration.',
      'err_connection': 'Connection error. Please try again.',
      'err_generic_title': 'Something went wrong',
      'action_try_again': 'Try Again',

      // Feed UI
      'feed_language': 'Language',
      'feed_categories': 'Categories',
      'feed_all': 'All',
      'feed_stories_count': '{n} stories',
      'feed_empty_title': 'No stories yet',
      'feed_empty_subtitle': 'Check back soon.',

      // Category names (by slug)
      'cat_general': 'General',
      'cat_politics': 'Politics',
      'cat_sports': 'Sports',
      'cat_technology': 'Technology',
      'cat_entertainment': 'Entertainment',
      'cat_business': 'Business',
      'cat_health': 'Health',
      'cat_local': 'Local',
    },
    'hi': {
      'tab_feed': 'फ़ीड',
      'tab_saved': 'सेव',
      'tab_settings': 'सेटिंग्स',
      'tab_home': 'होम',
      'tab_my_posts': 'मेरी पोस्ट्स',
      'tab_dashboard': 'डैशबोर्ड',
      'tab_pending': 'पेंडिंग',
      'tab_users': 'यूज़र्स',
      'settings_title': 'सेटिंग्स',
      'signin_access_settings': 'सेटिंग्स के लिए साइन इन करें',
      'action_signin': 'साइन इन',
      'section_account': 'अकाउंट',
      'section_appearance': 'दिखावट',
      'section_app': 'ऐप',
      'section_account_status': 'अकाउंट स्टेटस',
      'tile_edit_profile': 'प्रोफ़ाइल एडिट करें',
      'tile_change_password': 'पासवर्ड बदलें',
      'tile_notification_prefs': 'नोटिफिकेशन सेटिंग्स',
      'tile_become_reporter': 'रिपोर्टर बनें',
      'become_reporter_msg':
          'रिपोर्टर बनने के लिए नया रिपोर्टर अकाउंट बनाना होगा। हम आपको साइन आउट करके रिपोर्टर साइन-अप स्क्रीन पर ले जाएंगे।',
      'tile_privacy_policy': 'प्राइवेसी पॉलिसी',
      'tile_about': 'NewsNow के बारे में',
      'tile_help_support': 'हेल्प & सपोर्ट',
      'tile_clear_cache': 'कैश साफ़ करें',
      'tile_clear_cache_sub': 'इमेज और लोकल टेम्प फाइलें',
      'action_signout': 'साइन आउट',
      'confirm_signout_title': 'साइन आउट',
      'confirm_signout_msg': 'क्या आप वाकई साइन आउट करना चाहते हैं?',
      'confirm_clear_cache_title': 'कैश साफ़ करें',
      'confirm_clear_cache_msg':
          'यह इमेज कैश और लोकल टेम्प फाइलें हटाएगा। कुछ इमेज फिर से लोड होंगी।',
      'confirm_continue': 'जारी रखें',
      'snack_cache_cleared': 'कैश साफ़ हो गया',
      'privacy_title': 'प्राइवेसी पॉलिसी',
      'privacy_last_updated': 'अंतिम अपडेट: Apr 22, 2026',
      'privacy_placeholder':
          'यह NewsNow के लिए प्लेसहोल्डर प्राइवेसी पॉलिसी है। प्रोडक्शन से पहले इसे अपनी वास्तविक पॉलिसी से बदलें।',
      'privacy_collect_title': 'हम क्या एकत्र करते हैं',
      'privacy_collect_body':
          '- अकाउंट जानकारी (नाम, ईमेल/फोन)\n- उपयोग एनालिटिक्स (वैकल्पिक)\n- नोटिफिकेशन के लिए डिवाइस टोकन (यदि सक्षम)',
      'privacy_use_title': 'हम इसका उपयोग कैसे करते हैं',
      'privacy_use_body':
          'न्यूज़ फ़ीड दिखाने, यूज़र्स को ऑथेंटिकेट करने, नोटिफिकेशन भेजने और ऐप की विश्वसनीयता सुधारने के लिए।',
      'privacy_contact_title': 'संपर्क',
      'privacy_contact_body': 'यदि आपके कोई सवाल हैं, तो ऐप एडमिन से संपर्क करें।',

      // Auth - Register
      'reg_title': 'अकाउंट बनाएँ',
      'reg_subtitle': 'NewsNow से जुड़ें — अपनी जानकारी भरें',
      'reg_have_account': 'पहले से अकाउंट है? ',
      'action_create_account': 'अकाउंट बनाएँ',
      'field_full_name': 'पूरा नाम',
      'hint_full_name': 'जैसे: रवि कुमार',
      'field_email': 'ईमेल',
      'hint_email': 'you@example.com',
      'field_phone': 'मोबाइल नंबर',
      'hint_phone_optional': '+91 98765 43210 (वैकल्पिक)',
      'field_password': 'पासवर्ड',
      'hint_password': 'कम से कम 6 अक्षर, अक्षर + नंबर',
      'field_confirm_password': 'पासवर्ड कन्फर्म करें',
      'hint_confirm_password': 'पासवर्ड फिर से लिखें',

      // Auth - Login
      'login_subtitle': 'अपने अकाउंट में साइन इन करें',
      'login_admin_note': 'एडमिन को पासवर्ड से ही लॉगिन करना होगा। रिपोर्टर और यूज़र दोनों तरीकों से कर सकते हैं।',
      'login_hint_password': 'अपना पासवर्ड लिखें',
      'login_otp_note': 'आपके रजिस्टर्ड ईमेल या मोबाइल पर 6 अंकों का OTP भेजा जाएगा।',
      'login_field_target': 'ईमेल या मोबाइल नंबर',
      'login_hint_target': 'you@example.com  या  +91 98765 43210',
      'login_send_otp': 'OTP भेजें',
      'login_change_target': 'नंबर / ईमेल बदलें',
      'login_code_sent_to': 'कोड भेजा गया',
      'login_verify_signin': 'वेरिफाई करें और साइन इन',
      'login_code_expires': 'कोड 10 मिनट में एक्सपायर होगा',

      // Validation errors
      'err_email_required': 'ईमेल आवश्यक है',
      'err_email_invalid': 'कृपया सही ईमेल लिखें',
      'err_password_required': 'पासवर्ड आवश्यक है',
      'err_password_min': 'कम से कम 6 अक्षर',
      'err_target_required': 'ईमेल या मोबाइल नंबर आवश्यक है',
      'err_target_invalid': 'कृपया सही ईमेल या मोबाइल नंबर लिखें',

      // Register validation + API errors
      'err_name_required': 'पूरा नाम आवश्यक है',
      'err_name_min': 'कम से कम 2 अक्षर',
      'err_name_max': '60 अक्षरों से अधिक नहीं',
      'err_name_invalid': 'कृपया सही नाम लिखें',
      'err_phone_invalid': 'कृपया सही मोबाइल नंबर लिखें',
      'err_password_letter': 'कम से कम एक अक्षर होना चाहिए',
      'err_password_number': 'कम से कम एक नंबर होना चाहिए',
      'err_confirm_required': 'कृपया पासवर्ड कन्फर्म करें',
      'err_confirm_mismatch': 'पासवर्ड मेल नहीं खाते',
      'err_reg_email_required': 'रजिस्ट्रेशन के लिए ईमेल आवश्यक है।',
      'err_connection': 'कनेक्शन एरर। कृपया फिर से कोशिश करें।',
      'err_generic_title': 'कुछ गलत हो गया',
      'action_try_again': 'फिर से कोशिश करें',

      // Feed UI
      'feed_language': 'भाषा',
      'feed_categories': 'श्रेणियाँ',
      'feed_all': 'सभी',
      'feed_stories_count': '{n} स्टोरीज़',
      'feed_empty_title': 'अभी कोई स्टोरी नहीं',
      'feed_empty_subtitle': 'थोड़ी देर बाद फिर देखें।',

      // Category names
      'cat_general': 'जनरल',
      'cat_politics': 'राजनीति',
      'cat_sports': 'खेल',
      'cat_technology': 'टेक्नोलॉजी',
      'cat_entertainment': 'मनोरंजन',
      'cat_business': 'बिज़नेस',
      'cat_health': 'स्वास्थ्य',
      'cat_local': 'लोकल',
    },
    'te': {
      'tab_feed': 'ఫీడ్',
      'tab_saved': 'సేవ్',
      'tab_settings': 'సెట్టింగ్స్',
      'tab_home': 'హోమ్',
      'tab_my_posts': 'నా పోస్టులు',
      'tab_dashboard': 'డ్యాష్‌బోర్డ్',
      'tab_pending': 'పెండింగ్',
      'tab_users': 'వినియోగదారులు',
      'settings_title': 'సెట్టింగ్స్',
      'signin_access_settings': 'సెట్టింగ్స్ కోసం సైన్ ఇన్ చేయండి',
      'action_signin': 'సైన్ ఇన్',
      'section_account': 'ఖాతా',
      'section_appearance': 'రూపం',
      'section_app': 'యాప్',
      'section_account_status': 'ఖాతా స్థితి',
      'tile_edit_profile': 'ప్రొఫైల్ సవరించు',
      'tile_change_password': 'పాస్‌వర్డ్ మార్చు',
      'tile_notification_prefs': 'నోటిఫికేషన్ సెట్టింగ్స్',
      'tile_become_reporter': 'రిపోర్టర్ అవ్వండి',
      'become_reporter_msg':
          'రిపోర్టర్‌గా నమోదు కావడానికి కొత్త రిపోర్టర్ ఖాతా అవసరం. మేము సైన్ అవుట్ చేసి రిపోర్టర్ సైన్-అప్ స్క్రీన్‌కు తీసుకెళ్తాం.',
      'tile_privacy_policy': 'గోప్యతా విధానం',
      'tile_about': 'NewsNow గురించి',
      'tile_help_support': 'సహాయం & సపోర్ట్',
      'tile_clear_cache': 'క్యాష్ క్లియర్ చేయండి',
      'tile_clear_cache_sub': 'చిత్రాలు మరియు లోకల్ టెంప్ ఫైళ్లు',
      'action_signout': 'సైన్ అవుట్',
      'confirm_signout_title': 'సైన్ అవుట్',
      'confirm_signout_msg': 'మీరు నిజంగా సైన్ అవుట్ కావాలా?',
      'confirm_clear_cache_title': 'క్యాష్ క్లియర్ చేయండి',
      'confirm_clear_cache_msg':
          'ఇది ఇమేజ్ క్యాష్ మరియు లోకల్ టెంప్ ఫైళ్లను క్లియర్ చేస్తుంది. కొంత కంటెంట్ మళ్లీ లోడ్ అవుతుంది.',
      'confirm_continue': 'కొనసాగించండి',
      'snack_cache_cleared': 'క్యాష్ క్లియర్ అయింది',
      'privacy_title': 'గోప్యతా విధానం',
      'privacy_last_updated': 'చివరి నవీకరణ: Apr 22, 2026',
      'privacy_placeholder':
          'ఇది NewsNow కోసం ప్లేస్‌హోల్డర్ గోప్యతా విధానం. ప్రొడక్షన్ ముందు మీ నిజమైన పాలసీతో మార్చండి.',
      'privacy_collect_title': 'మేము ఏమి సేకరిస్తాం',
      'privacy_collect_body':
          '- ఖాతా సమాచారం (పేరు, ఇమెయిల్/ఫోన్)\n- వినియోగ విశ్లేషణ (ఐచ్చికం)\n- నోటిఫికేషన్‌ల కోసం డివైస్ టోకెన్స్ (ఎనేబుల్ చేసినట్లయితే)',
      'privacy_use_title': 'మేము ఎలా ఉపయోగిస్తాం',
      'privacy_use_body':
          'న్యూస్ ఫీడ్ అందించడానికి, లాగిన్ నిర్వహించడానికి, నోటిఫికేషన్‌లు పంపడానికి మరియు యాప్ నమ్మకత్వాన్ని మెరుగుపరచడానికి.',
      'privacy_contact_title': 'సంప్రదించండి',
      'privacy_contact_body': 'ప్రశ్నలు ఉంటే, యాప్ అడ్మిన్‌ను సంప్రదించండి.',

      // Auth - Register
      'reg_title': 'ఖాతా సృష్టించండి',
      'reg_subtitle': 'NewsNow లో చేరండి — మీ వివరాలు నమోదు చేయండి',
      'reg_have_account': 'ఇప్పటికే ఖాతా ఉందా? ',
      'action_create_account': 'ఖాతా సృష్టించండి',
      'field_full_name': 'పూర్తి పేరు',
      'hint_full_name': 'ఉదా: రవి కుమార్',
      'field_email': 'ఇమెయిల్',
      'hint_email': 'you@example.com',
      'field_phone': 'మొబైల్ నంబర్',
      'hint_phone_optional': '+91 98765 43210 (ఐచ్చికం)',
      'field_password': 'పాస్‌వర్డ్',
      'hint_password': 'కనీసం 6 అక్షరాలు, అక్షరాలు + నంబర్లు',
      'field_confirm_password': 'పాస్‌వర్డ్ నిర్ధారించండి',
      'hint_confirm_password': 'పాస్‌వర్డ్ మళ్లీ నమోదు చేయండి',

      // Auth - Login
      'login_subtitle': 'మీ ఖాతాలో సైన్ ఇన్ చేయండి',
      'login_admin_note': 'అడ్మిన్లు తప్పనిసరిగా పాస్‌వర్డ్‌తో లాగిన్ చేయాలి. రిపోర్టర్లు మరియు యూజర్లు ఏ విధానమైనా ఉపయోగించవచ్చు.',
      'login_hint_password': 'మీ పాస్‌వర్డ్ నమోదు చేయండి',
      'login_otp_note': 'మీ రిజిస్టర్ అయిన ఇమెయిల్ లేదా మొబైల్‌కు 6 అంకెల OTP పంపబడుతుంది.',
      'login_field_target': 'ఇమెయిల్ లేదా మొబైల్ నంబర్',
      'login_hint_target': 'you@example.com  లేదా  +91 98765 43210',
      'login_send_otp': 'OTP పంపండి',
      'login_change_target': 'నంబర్ / ఇమెయిల్ మార్చండి',
      'login_code_sent_to': 'కోడ్ పంపబడింది',
      'login_verify_signin': 'ధృవీకరించి సైన్ ఇన్ చేయండి',
      'login_code_expires': 'కోడ్ 10 నిమిషాల్లో ముగుస్తుంది',

      // Validation errors
      'err_email_required': 'ఇమెయిల్ అవసరం',
      'err_email_invalid': 'సరైన ఇమెయిల్ నమోదు చేయండి',
      'err_password_required': 'పాస్‌వర్డ్ అవసరం',
      'err_password_min': 'కనీసం 6 అక్షరాలు',
      'err_target_required': 'ఇమెయిల్ లేదా మొబైల్ నంబర్ అవసరం',
      'err_target_invalid': 'సరైన ఇమెయిల్ లేదా మొబైల్ నంబర్ నమోదు చేయండి',

      // Register validation + API errors
      'err_name_required': 'పూర్తి పేరు అవసరం',
      'err_name_min': 'కనీసం 2 అక్షరాలు',
      'err_name_max': '60 అక్షరాలకంటే ఎక్కువ కాదు',
      'err_name_invalid': 'సరైన పేరు నమోదు చేయండి',
      'err_phone_invalid': 'సరైన మొబైల్ నంబర్ నమోదు చేయండి',
      'err_password_letter': 'కనీసం ఒక అక్షరం ఉండాలి',
      'err_password_number': 'కనీసం ఒక సంఖ్య ఉండాలి',
      'err_confirm_required': 'దయచేసి పాస్‌వర్డ్ నిర్ధారించండి',
      'err_confirm_mismatch': 'పాస్‌వర్డ్‌లు సరిపోలడం లేదు',
      'err_reg_email_required': 'రిజిస్ట్రేషన్ కోసం ఇమెయిల్ అవసరం.',
      'err_connection': 'కనెక్షన్ లోపం. మళ్లీ ప్రయత్నించండి.',
      'err_generic_title': 'ఏదో తప్పు జరిగింది',
      'action_try_again': 'మళ్లీ ప్రయత్నించండి',

      // Feed UI
      'feed_language': 'భాష',
      'feed_categories': 'వర్గాలు',
      'feed_all': 'అన్నీ',
      'feed_stories_count': '{n} స్టోరీలు',
      'feed_empty_title': 'ఇంకా స్టోరీలు లేవు',
      'feed_empty_subtitle': 'కొంతసేపటికి మళ్లీ చూడండి.',

      // Category names
      'cat_general': 'సాధారణం',
      'cat_politics': 'రాజకీయాలు',
      'cat_sports': 'క్రీడలు',
      'cat_technology': 'టెక్నాలజీ',
      'cat_entertainment': 'వినోదం',
      'cat_business': 'వ్యాపారం',
      'cat_health': 'ఆరోగ్యం',
      'cat_local': 'లోకల్',
    },
    // Treat "all" as English for UI labels
    'all': {},
  };
}

