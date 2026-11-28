import 'auth.dart' show AuthPage;
import 'health.dart';
import 'i18n.dart';
import 'sharecard.dart';
// Nilo World: passport (stamps, XP, streak), home country, daily word/puzzle, chapters, papyrus trip animation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:http/http.dart' as http;
import 'main.dart';
import 'settings.dart';
import 'journey.dart';
import 'trip.dart';
import 'namecard.dart';
import 'papyrus_globe.dart';
import 'screens.dart' show toast, ToolsPage;

/// code, English name, Arabic name, flag, lat, lon, symbol emoji, symbol name, hello, thanks
const List<List<Object>> kWorld = [
  ['EG', 'Egypt', 'مصر', '🇪🇬', 30.0, 31.2, '🔺', 'Pyramid', 'مرحبا', 'شكرا'],
  ['JP', 'Japan', 'اليابان', '🇯🇵', 35.7, 139.7, '🪁', 'Kite', 'こんにちは', 'ありがとう'],
  ['FR', 'France', 'فرنسا', '🇫🇷', 48.9, 2.35, '✒️', 'Quill pen', 'Bonjour', 'Merci'],
  ['CA', 'Canada', 'كندا', '🇨🇦', 45.4, -75.7, '🍁', 'Maple leaf', 'Hello', 'Thank you'],
  ['RU', 'Russia', 'روسيا', '🇷🇺', 55.75, 37.6, '🪆', 'Matryoshka doll', 'Привет', 'Спасибо'],
  ['UA', 'Ukraine', 'أوكرانيا', '🇺🇦', 50.45, 30.5, '🌻', 'Sunflower', 'Привіт', 'Дякую'],
  ['US', 'United States', 'أمريكا', '🇺🇸', 38.9, -77.0, '🗽', 'Statue of Liberty', 'Hello', 'Thank you'],
  ['GB', 'United Kingdom', 'بريطانيا', '🇬🇧', 51.5, -0.12, '🕰️', 'Clock tower', 'Hello', 'Thank you'],
  ['DE', 'Germany', 'ألمانيا', '🇩🇪', 52.5, 13.4, '🥨', 'Pretzel', 'Hallo', 'Danke'],
  ['IT', 'Italy', 'إيطاليا', '🇮🇹', 41.9, 12.5, '🏛️', 'Colosseum', 'Ciao', 'Grazie'],
  ['ES', 'Spain', 'إسبانيا', '🇪🇸', 40.4, -3.7, '💃', 'Flamenco dancer', 'Hola', 'Gracias'],
  ['TR', 'Turkey', 'تركيا', '🇹🇷', 39.9, 32.9, '🎈', 'Hot air balloon', 'Merhaba', 'Teşekkürler'],
  ['SA', 'Saudi Arabia', 'السعودية', '🇸🇦', 24.7, 46.7, '🌴', 'Palm tree', 'مرحبا', 'شكرا'],
  ['IN', 'India', 'الهند', '🇮🇳', 28.6, 77.2, '🪔', 'Diya lamp', 'नमस्ते', 'धन्यवाद'],
  ['CN', 'China', 'الصين', '🇨🇳', 39.9, 116.4, '🐼', 'Panda', '你好', '谢谢'],
  ['BR', 'Brazil', 'البرازيل', '🇧🇷', -15.8, -47.9, '🦜', 'Parrot', 'Olá', 'Obrigado'],
  ['MX', 'Mexico', 'المكسيك', '🇲🇽', 19.4, -99.1, '🌵', 'Cactus', 'Hola', 'Gracias'],
  ['KR', 'South Korea', 'كوريا الجنوبية', '🇰🇷', 37.6, 127.0, '🏯', 'Palace', '안녕하세요', '감사합니다'],
  ['AU', 'Australia', 'أستراليا', '🇦🇺', -35.3, 149.1, '🦘', 'Kangaroo', 'Hello', 'Thank you'],
  // Full ISO 3166-1 list (names from Unicode CLDR, label points from Natural Earth, public domain). Entries below have no story symbol or greeting yet.
  ['AF', 'Afghanistan', 'أفغانستان', '🇦🇫', 34.16, 66.50, '🇦🇫', 'Flag', '', ''],
  ['AL', 'Albania', 'ألبانيا', '🇦🇱', 40.65, 20.11, '🇦🇱', 'Flag', '', ''],
  ['DZ', 'Algeria', 'الجزائر', '🇩🇿', 27.40, 2.81, '🇩🇿', 'Flag', '', ''],
  ['AS', 'American Samoa', 'ساموا الأمريكية', '🇦🇸', -14.33, -170.75, '🇦🇸', 'Flag', '', ''],
  ['AD', 'Andorra', 'أندورا', '🇦🇩', 42.55, 1.54, '🇦🇩', 'Flag', '', ''],
  ['AO', 'Angola', 'أنغولا', '🇦🇴', -12.18, 17.98, '🇦🇴', 'Flag', '', ''],
  ['AI', 'Anguilla', 'أنغويلا', '🇦🇮', 18.24, -63.03, '🇦🇮', 'Flag', '', ''],
  ['AQ', 'Antarctica', 'أنتاركتيكا', '🇦🇶', -79.84, 35.89, '🇦🇶', 'Flag', '', ''],
  ['AG', 'Antigua & Barbuda', 'أنتيغوا وبربودا', '🇦🇬', 17.35, -61.79, '🇦🇬', 'Flag', '', ''],
  ['AR', 'Argentina', 'الأرجنتين', '🇦🇷', -33.50, -64.17, '🇦🇷', 'Flag', '', ''],
  ['AM', 'Armenia', 'أرمينيا', '🇦🇲', 40.46, 44.80, '🇦🇲', 'Flag', '', ''],
  ['AW', 'Aruba', 'أروبا', '🇦🇼', 12.52, -69.97, '🇦🇼', 'Flag', '', ''],
  ['AT', 'Austria', 'النمسا', '🇦🇹', 47.52, 14.13, '🇦🇹', 'Flag', '', ''],
  ['AZ', 'Azerbaijan', 'أذربيجان', '🇦🇿', 40.40, 47.21, '🇦🇿', 'Flag', '', ''],
  ['BS', 'Bahamas', 'جزر البهاما', '🇧🇸', 26.40, -77.15, '🇧🇸', 'Flag', '', ''],
  ['BH', 'Bahrain', 'البحرين', '🇧🇭', 26.06, 50.55, '🇧🇭', 'Flag', '', ''],
  ['BD', 'Bangladesh', 'بنغلاديش', '🇧🇩', 24.21, 89.68, '🇧🇩', 'Flag', '', ''],
  ['BB', 'Barbados', 'بربادوس', '🇧🇧', 13.16, -59.57, '🇧🇧', 'Flag', '', ''],
  ['BY', 'Belarus', 'بيلاروس', '🇧🇾', 53.82, 28.42, '🇧🇾', 'Flag', '', ''],
  ['BE', 'Belgium', 'بلجيكا', '🇧🇪', 50.79, 4.80, '🇧🇪', 'Flag', '', ''],
  ['BZ', 'Belize', 'بليز', '🇧🇿', 17.20, -88.71, '🇧🇿', 'Flag', '', ''],
  ['BJ', 'Benin', 'بنين', '🇧🇯', 10.32, 2.35, '🇧🇯', 'Flag', '', ''],
  ['BM', 'Bermuda', 'برمودا', '🇧🇲', 32.30, -64.76, '🇧🇲', 'Flag', '', ''],
  ['BT', 'Bhutan', 'بوتان', '🇧🇹', 27.54, 90.04, '🇧🇹', 'Flag', '', ''],
  ['BO', 'Bolivia', 'بوليفيا', '🇧🇴', -16.67, -64.59, '🇧🇴', 'Flag', '', ''],
  ['BA', 'Bosnia & Herzegovina', 'البوسنة والهرسك', '🇧🇦', 44.09, 18.07, '🇧🇦', 'Flag', '', ''],
  ['BW', 'Botswana', 'بوتسوانا', '🇧🇼', -22.10, 24.18, '🇧🇼', 'Flag', '', ''],
  ['IO', 'British Indian Ocean Territory', 'الإقليم البريطاني في المحيط الهندي', '🇮🇴', -6.19, 71.35, '🇮🇴', 'Flag', '', ''],
  ['VG', 'British Virgin Islands', 'جزر فيرجن البريطانية', '🇻🇬', 18.43, -64.64, '🇻🇬', 'Flag', '', ''],
  ['BN', 'Brunei', 'بروناي', '🇧🇳', 4.45, 114.55, '🇧🇳', 'Flag', '', ''],
  ['BG', 'Bulgaria', 'بلغاريا', '🇧🇬', 42.51, 25.16, '🇧🇬', 'Flag', '', ''],
  ['BF', 'Burkina Faso', 'بوركينا فاسو', '🇧🇫', 12.67, -1.36, '🇧🇫', 'Flag', '', ''],
  ['BI', 'Burundi', 'بوروندي', '🇧🇮', -3.33, 29.92, '🇧🇮', 'Flag', '', ''],
  ['KH', 'Cambodia', 'كمبوديا', '🇰🇭', 12.65, 104.50, '🇰🇭', 'Flag', '', ''],
  ['CM', 'Cameroon', 'الكاميرون', '🇨🇲', 4.59, 12.47, '🇨🇲', 'Flag', '', ''],
  ['CV', 'Cape Verde', 'الرأس الأخضر', '🇨🇻', 15.07, -23.64, '🇨🇻', 'Flag', '', ''],
  ['KY', 'Cayman Islands', 'جزر كايمان', '🇰🇾', 19.32, -81.24, '🇰🇾', 'Flag', '', ''],
  ['CF', 'Central African Republic', 'جمهورية أفريقيا الوسطى', '🇨🇫', 6.99, 20.91, '🇨🇫', 'Flag', '', ''],
  ['TD', 'Chad', 'تشاد', '🇹🇩', 15.14, 18.65, '🇹🇩', 'Flag', '', ''],
  ['CL', 'Chile', 'تشيلي', '🇨🇱', -38.15, -72.32, '🇨🇱', 'Flag', '', ''],
  ['CO', 'Colombia', 'كولومبيا', '🇨🇴', 3.37, -73.17, '🇨🇴', 'Flag', '', ''],
  ['KM', 'Comoros', 'جزر القمر', '🇰🇲', -11.73, 43.32, '🇰🇲', 'Flag', '', ''],
  ['CG', 'Congo - Brazzaville', 'الكونغو - برازافيل', '🇨🇬', 0.14, 15.90, '🇨🇬', 'Flag', '', ''],
  ['CD', 'Congo - Kinshasa', 'الكونغو - كينشاسا', '🇨🇩', -1.86, 23.46, '🇨🇩', 'Flag', '', ''],
  ['CK', 'Cook Islands', 'جزر كوك', '🇨🇰', -21.22, -159.79, '🇨🇰', 'Flag', '', ''],
  ['CR', 'Costa Rica', 'كوستاريكا', '🇨🇷', 10.07, -84.08, '🇨🇷', 'Flag', '', ''],
  ['HR', 'Croatia', 'كرواتيا', '🇭🇷', 45.81, 16.37, '🇭🇷', 'Flag', '', ''],
  ['CU', 'Cuba', 'كوبا', '🇨🇺', 21.33, -77.98, '🇨🇺', 'Flag', '', ''],
  ['CW', 'Curaçao', 'كوراساو', '🇨🇼', 12.15, -68.92, '🇨🇼', 'Flag', '', ''],
  ['CY', 'Cyprus', 'قبرص', '🇨🇾', 34.91, 33.08, '🇨🇾', 'Flag', '', ''],
  ['CZ', 'Czechia', 'التشيك', '🇨🇿', 49.88, 15.38, '🇨🇿', 'Flag', '', ''],
  ['CI', 'Côte d’Ivoire', 'ساحل العاج', '🇨🇮', 7.49, -5.57, '🇨🇮', 'Flag', '', ''],
  ['DK', 'Denmark', 'الدانمرك', '🇩🇰', 55.97, 9.02, '🇩🇰', 'Flag', '', ''],
  ['DJ', 'Djibouti', 'جيبوتي', '🇩🇯', 11.98, 42.50, '🇩🇯', 'Flag', '', ''],
  ['DM', 'Dominica', 'دومينيكا', '🇩🇲', 15.46, -61.34, '🇩🇲', 'Flag', '', ''],
  ['DO', 'Dominican Republic', 'جمهورية الدومينيكان', '🇩🇴', 19.10, -70.65, '🇩🇴', 'Flag', '', ''],
  ['EC', 'Ecuador', 'الإكوادور', '🇪🇨', -1.26, -78.19, '🇪🇨', 'Flag', '', ''],
  ['SV', 'El Salvador', 'السلفادور', '🇸🇻', 13.69, -88.89, '🇸🇻', 'Flag', '', ''],
  ['GQ', 'Equatorial Guinea', 'غينيا الاستوائية', '🇬🇶', 2.33, 8.99, '🇬🇶', 'Flag', '', ''],
  ['ER', 'Eritrea', 'إريتريا', '🇪🇷', 15.79, 38.29, '🇪🇷', 'Flag', '', ''],
  ['EE', 'Estonia', 'إستونيا', '🇪🇪', 58.72, 25.87, '🇪🇪', 'Flag', '', ''],
  ['SZ', 'Eswatini', 'إسواتيني', '🇸🇿', -26.53, 31.47, '🇸🇿', 'Flag', '', ''],
  ['ET', 'Ethiopia', 'إثيوبيا', '🇪🇹', 8.03, 39.09, '🇪🇹', 'Flag', '', ''],
  ['FK', 'Falkland Islands', 'جزر فوكلاند', '🇫🇰', -51.61, -58.74, '🇫🇰', 'Flag', '', ''],
  ['FO', 'Faroe Islands', 'جزر فارو', '🇫🇴', 62.19, -7.06, '🇫🇴', 'Flag', '', ''],
  ['FJ', 'Fiji', 'فيجي', '🇫🇯', -17.83, 177.98, '🇫🇯', 'Flag', '', ''],
  ['FI', 'Finland', 'فنلندا', '🇫🇮', 63.25, 27.28, '🇫🇮', 'Flag', '', ''],
  ['PF', 'French Polynesia', 'بولينيزيا الفرنسية', '🇵🇫', -17.63, -149.46, '🇵🇫', 'Flag', '', ''],
  ['TF', 'French Southern Territories', 'الأقاليم الجنوبية الفرنسية', '🇹🇫', -49.30, 69.12, '🇹🇫', 'Flag', '', ''],
  ['GA', 'Gabon', 'الغابون', '🇬🇦', -0.44, 11.84, '🇬🇦', 'Flag', '', ''],
  ['GM', 'Gambia', 'غامبيا', '🇬🇲', 13.64, -15.00, '🇬🇲', 'Flag', '', ''],
  ['GE', 'Georgia', 'جورجيا', '🇬🇪', 41.87, 43.74, '🇬🇪', 'Flag', '', ''],
  ['GH', 'Ghana', 'غانا', '🇬🇭', 7.72, -1.04, '🇬🇭', 'Flag', '', ''],
  ['GR', 'Greece', 'اليونان', '🇬🇷', 39.49, 21.73, '🇬🇷', 'Flag', '', ''],
  ['GL', 'Greenland', 'غرينلاند', '🇬🇱', 74.32, -39.34, '🇬🇱', 'Flag', '', ''],
  ['GD', 'Grenada', 'غرينادا', '🇬🇩', 12.11, -61.68, '🇬🇩', 'Flag', '', ''],
  ['GU', 'Guam', 'غوام', '🇬🇺', 13.35, 144.70, '🇬🇺', 'Flag', '', ''],
  ['GT', 'Guatemala', 'غواتيمالا', '🇬🇹', 14.98, -90.50, '🇬🇹', 'Flag', '', ''],
  ['GG', 'Guernsey', 'غيرنزي', '🇬🇬', 49.46, -2.56, '🇬🇬', 'Flag', '', ''],
  ['GN', 'Guinea', 'غينيا', '🇬🇳', 10.62, -10.02, '🇬🇳', 'Flag', '', ''],
  ['GW', 'Guinea-Bissau', 'غينيا بيساو', '🇬🇼', 12.16, -14.52, '🇬🇼', 'Flag', '', ''],
  ['GY', 'Guyana', 'غيانا', '🇬🇾', 5.12, -58.94, '🇬🇾', 'Flag', '', ''],
  ['HT', 'Haiti', 'هايتي', '🇭🇹', 19.26, -72.22, '🇭🇹', 'Flag', '', ''],
  ['HM', 'Heard & McDonald Islands', 'جزيرة هيرد وجزر ماكدونالد', '🇭🇲', -53.10, 73.51, '🇭🇲', 'Flag', '', ''],
  ['HN', 'Honduras', 'هندوراس', '🇭🇳', 14.79, -86.89, '🇭🇳', 'Flag', '', ''],
  ['HK', 'Hong Kong SAR China', 'هونغ كونغ الصينية (منطقة إدارية خاصة)', '🇭🇰', 22.45, 114.10, '🇭🇰', 'Flag', '', ''],
  ['HU', 'Hungary', 'هنغاريا', '🇭🇺', 47.09, 19.45, '🇭🇺', 'Flag', '', ''],
  ['IS', 'Iceland', 'آيسلندا', '🇮🇸', 64.78, -18.67, '🇮🇸', 'Flag', '', ''],
  ['ID', 'Indonesia', 'إندونيسيا', '🇮🇩', -0.95, 101.89, '🇮🇩', 'Flag', '', ''],
  ['IR', 'Iran', 'إيران', '🇮🇷', 32.17, 54.93, '🇮🇷', 'Flag', '', ''],
  ['IQ', 'Iraq', 'العراق', '🇮🇶', 33.09, 43.26, '🇮🇶', 'Flag', '', ''],
  ['IE', 'Ireland', 'أيرلندا', '🇮🇪', 53.08, -7.80, '🇮🇪', 'Flag', '', ''],
  ['IM', 'Isle of Man', 'جزيرة مان', '🇮🇲', 54.22, -4.53, '🇮🇲', 'Flag', '', ''],
  ['IL', 'Israel', 'إسرائيل', '🇮🇱', 30.91, 34.85, '🇮🇱', 'Flag', '', ''],
  ['JM', 'Jamaica', 'جامايكا', '🇯🇲', 18.14, -77.32, '🇯🇲', 'Flag', '', ''],
  ['JE', 'Jersey', 'جيرسي', '🇯🇪', 49.22, -2.09, '🇯🇪', 'Flag', '', ''],
  ['JO', 'Jordan', 'الأردن', '🇯🇴', 30.81, 36.38, '🇯🇴', 'Flag', '', ''],
  ['KZ', 'Kazakhstan', 'كازاخستان', '🇰🇿', 49.05, 68.69, '🇰🇿', 'Flag', '', ''],
  ['KE', 'Kenya', 'كينيا', '🇰🇪', 0.55, 37.91, '🇰🇪', 'Flag', '', ''],
  ['KI', 'Kiribati', 'كيريباتي', '🇰🇮', 1.82, -157.38, '🇰🇮', 'Flag', '', ''],
  ['KW', 'Kuwait', 'الكويت', '🇰🇼', 29.41, 47.31, '🇰🇼', 'Flag', '', ''],
  ['KG', 'Kyrgyzstan', 'قيرغيزستان', '🇰🇬', 41.67, 74.53, '🇰🇬', 'Flag', '', ''],
  ['LA', 'Laos', 'لاوس', '🇱🇦', 19.43, 102.53, '🇱🇦', 'Flag', '', ''],
  ['LV', 'Latvia', 'لاتفيا', '🇱🇻', 57.07, 25.46, '🇱🇻', 'Flag', '', ''],
  ['LB', 'Lebanon', 'لبنان', '🇱🇧', 34.13, 35.99, '🇱🇧', 'Flag', '', ''],
  ['LS', 'Lesotho', 'ليسوتو', '🇱🇸', -29.48, 28.25, '🇱🇸', 'Flag', '', ''],
  ['LR', 'Liberia', 'ليبيريا', '🇱🇷', 6.45, -9.46, '🇱🇷', 'Flag', '', ''],
  ['LY', 'Libya', 'ليبيا', '🇱🇾', 26.64, 18.01, '🇱🇾', 'Flag', '', ''],
  ['LI', 'Liechtenstein', 'ليختنشتاين', '🇱🇮', 47.11, 9.56, '🇱🇮', 'Flag', '', ''],
  ['LT', 'Lithuania', 'ليتوانيا', '🇱🇹', 55.10, 24.09, '🇱🇹', 'Flag', '', ''],
  ['LU', 'Luxembourg', 'لوكسمبورغ', '🇱🇺', 49.73, 6.08, '🇱🇺', 'Flag', '', ''],
  ['MO', 'Macao SAR China', 'منطقة ماكاو الإدارية الخاصة', '🇲🇴', 22.13, 113.56, '🇲🇴', 'Flag', '', ''],
  ['MG', 'Madagascar', 'مدغشقر', '🇲🇬', -18.63, 46.70, '🇲🇬', 'Flag', '', ''],
  ['MW', 'Malawi', 'ملاوي', '🇲🇼', -13.39, 33.61, '🇲🇼', 'Flag', '', ''],
  ['MY', 'Malaysia', 'ماليزيا', '🇲🇾', 2.53, 113.84, '🇲🇾', 'Flag', '', ''],
  ['MV', 'Maldives', 'جزر المالديف', '🇲🇻', 4.17, 73.51, '🇲🇻', 'Flag', '', ''],
  ['ML', 'Mali', 'مالي', '🇲🇱', 18.69, -2.04, '🇲🇱', 'Flag', '', ''],
  ['MT', 'Malta', 'مالطا', '🇲🇹', 35.89, 14.43, '🇲🇹', 'Flag', '', ''],
  ['MH', 'Marshall Islands', 'جزر مارشال', '🇲🇭', 7.08, 171.19, '🇲🇭', 'Flag', '', ''],
  ['MR', 'Mauritania', 'موريتانيا', '🇲🇷', 19.59, -9.74, '🇲🇷', 'Flag', '', ''],
  ['MU', 'Mauritius', 'موريشيوس', '🇲🇺', -20.30, 57.57, '🇲🇺', 'Flag', '', ''],
  ['FM', 'Micronesia', 'ميكرونيزيا', '🇫🇲', 6.89, 158.23, '🇫🇲', 'Flag', '', ''],
  ['MD', 'Moldova', 'مولدوفا', '🇲🇩', 47.43, 28.49, '🇲🇩', 'Flag', '', ''],
  ['MC', 'Monaco', 'موناكو', '🇲🇨', 43.74, 7.40, '🇲🇨', 'Flag', '', ''],
  ['MN', 'Mongolia', 'منغوليا', '🇲🇳', 46.00, 104.15, '🇲🇳', 'Flag', '', ''],
  ['ME', 'Montenegro', 'الجبل الأسود', '🇲🇪', 42.80, 19.14, '🇲🇪', 'Flag', '', ''],
  ['MS', 'Montserrat', 'مونتسرات', '🇲🇸', 16.74, -62.19, '🇲🇸', 'Flag', '', ''],
  ['MA', 'Morocco', 'المغرب', '🇲🇦', 31.65, -7.19, '🇲🇦', 'Flag', '', ''],
  ['MZ', 'Mozambique', 'موزمبيق', '🇲🇿', -13.94, 37.84, '🇲🇿', 'Flag', '', ''],
  ['MM', 'Myanmar (Burma)', 'ميانمار (بورما)', '🇲🇲', 21.57, 95.80, '🇲🇲', 'Flag', '', ''],
  ['NA', 'Namibia', 'ناميبيا', '🇳🇦', -20.58, 17.11, '🇳🇦', 'Flag', '', ''],
  ['NR', 'Nauru', 'ناورو', '🇳🇷', -0.52, 166.93, '🇳🇷', 'Flag', '', ''],
  ['NP', 'Nepal', 'نيبال', '🇳🇵', 28.30, 83.64, '🇳🇵', 'Flag', '', ''],
  ['NL', 'Netherlands', 'هولندا', '🇳🇱', 52.42, 5.61, '🇳🇱', 'Flag', '', ''],
  ['NC', 'New Caledonia', 'كاليدونيا الجديدة', '🇳🇨', -21.06, 165.08, '🇳🇨', 'Flag', '', ''],
  ['NZ', 'New Zealand', 'نيوزيلندا', '🇳🇿', -39.76, 172.79, '🇳🇿', 'Flag', '', ''],
  ['NI', 'Nicaragua', 'نيكاراغوا', '🇳🇮', 12.67, -85.07, '🇳🇮', 'Flag', '', ''],
  ['NE', 'Niger', 'النيجر', '🇳🇪', 17.45, 9.50, '🇳🇪', 'Flag', '', ''],
  ['NG', 'Nigeria', 'نيجيريا', '🇳🇬', 9.44, 7.50, '🇳🇬', 'Flag', '', ''],
  ['NU', 'Niue', 'نيوي', '🇳🇺', -19.05, -169.86, '🇳🇺', 'Flag', '', ''],
  ['NF', 'Norfolk Island', 'جزيرة نورفولك', '🇳🇫', -29.03, 167.95, '🇳🇫', 'Flag', '', ''],
  ['KP', 'North Korea', 'كوريا الشمالية', '🇰🇵', 39.89, 126.44, '🇰🇵', 'Flag', '', ''],
  ['MK', 'North Macedonia', 'مقدونيا الشمالية', '🇲🇰', 41.56, 21.56, '🇲🇰', 'Flag', '', ''],
  ['MP', 'Northern Mariana Islands', 'جزر ماريانا الشمالية', '🇲🇵', 15.19, 145.73, '🇲🇵', 'Flag', '', ''],
  ['NO', 'Norway', 'النرويج', '🇳🇴', 61.36, 9.68, '🇳🇴', 'Flag', '', ''],
  ['OM', 'Oman', 'عُمان', '🇴🇲', 22.12, 57.34, '🇴🇲', 'Flag', '', ''],
  ['PK', 'Pakistan', 'باكستان', '🇵🇰', 29.33, 68.55, '🇵🇰', 'Flag', '', ''],
  ['PW', 'Palau', 'بالاو', '🇵🇼', 7.52, 134.58, '🇵🇼', 'Flag', '', ''],
  ['PS', 'Palestinian Territories', 'الأراضي الفلسطينية', '🇵🇸', 32.05, 35.29, '🇵🇸', 'Flag', '', ''],
  ['PA', 'Panama', 'بنما', '🇵🇦', 8.72, -80.35, '🇵🇦', 'Flag', '', ''],
  ['PG', 'Papua New Guinea', 'بابوا غينيا الجديدة', '🇵🇬', -5.70, 143.91, '🇵🇬', 'Flag', '', ''],
  ['PY', 'Paraguay', 'باراغواي', '🇵🇾', -21.67, -60.15, '🇵🇾', 'Flag', '', ''],
  ['PE', 'Peru', 'بيرو', '🇵🇪', -12.98, -72.90, '🇵🇪', 'Flag', '', ''],
  ['PH', 'Philippines', 'الفلبين', '🇵🇭', 11.20, 122.47, '🇵🇭', 'Flag', '', ''],
  ['PN', 'Pitcairn Islands', 'جزر بيتكيرن', '🇵🇳', -24.36, -128.32, '🇵🇳', 'Flag', '', ''],
  ['PL', 'Poland', 'بولندا', '🇵🇱', 51.99, 19.49, '🇵🇱', 'Flag', '', ''],
  ['PT', 'Portugal', 'البرتغال', '🇵🇹', 39.61, -8.27, '🇵🇹', 'Flag', '', ''],
  ['PR', 'Puerto Rico', 'بورتوريكو', '🇵🇷', 18.23, -66.48, '🇵🇷', 'Flag', '', ''],
  ['QA', 'Qatar', 'قطر', '🇶🇦', 25.24, 51.14, '🇶🇦', 'Flag', '', ''],
  ['RO', 'Romania', 'رومانيا', '🇷🇴', 45.73, 24.97, '🇷🇴', 'Flag', '', ''],
  ['RW', 'Rwanda', 'رواندا', '🇷🇼', -1.90, 30.10, '🇷🇼', 'Flag', '', ''],
  ['WS', 'Samoa', 'ساموا', '🇼🇸', -13.64, -172.44, '🇼🇸', 'Flag', '', ''],
  ['SM', 'San Marino', 'سان مارينو', '🇸🇲', 43.93, 12.44, '🇸🇲', 'Flag', '', ''],
  ['SN', 'Senegal', 'السنغال', '🇸🇳', 15.14, -14.78, '🇸🇳', 'Flag', '', ''],
  ['RS', 'Serbia', 'صربيا', '🇷🇸', 44.19, 20.79, '🇷🇸', 'Flag', '', ''],
  ['SC', 'Seychelles', 'سيشل', '🇸🇨', -4.68, 55.48, '🇸🇨', 'Flag', '', ''],
  ['SL', 'Sierra Leone', 'سيراليون', '🇸🇱', 8.62, -11.76, '🇸🇱', 'Flag', '', ''],
  ['SG', 'Singapore', 'سنغافورة', '🇸🇬', 1.37, 103.82, '🇸🇬', 'Flag', '', ''],
  ['SX', 'Sint Maarten', 'سانت مارتن', '🇸🇽', 18.04, -63.07, '🇸🇽', 'Flag', '', ''],
  ['SK', 'Slovakia', 'سلوفاكيا', '🇸🇰', 48.73, 19.05, '🇸🇰', 'Flag', '', ''],
  ['SI', 'Slovenia', 'سلوفينيا', '🇸🇮', 46.06, 14.92, '🇸🇮', 'Flag', '', ''],
  ['SB', 'Solomon Islands', 'جزر سليمان', '🇸🇧', -8.03, 159.17, '🇸🇧', 'Flag', '', ''],
  ['SO', 'Somalia', 'الصومال', '🇸🇴', 3.57, 45.19, '🇸🇴', 'Flag', '', ''],
  ['ZA', 'South Africa', 'جنوب أفريقيا', '🇿🇦', -29.71, 23.67, '🇿🇦', 'Flag', '', ''],
  ['GS', 'South Georgia & South Sandwich Islands', 'جورجيا الجنوبية وجزر ساندويتش الجنوبية', '🇬🇸', -55.68, -31.06, '🇬🇸', 'Flag', '', ''],
  ['SS', 'South Sudan', 'جنوب السودان', '🇸🇸', 7.23, 30.39, '🇸🇸', 'Flag', '', ''],
  ['LK', 'Sri Lanka', 'سريلانكا', '🇱🇰', 7.58, 80.70, '🇱🇰', 'Flag', '', ''],
  ['BL', 'St. Barthélemy', 'سان بارتليمي', '🇧🇱', 17.90, -62.83, '🇧🇱', 'Flag', '', ''],
  ['SH', 'St. Helena', 'سانت هيلينا', '🇸🇭', -15.95, -5.71, '🇸🇭', 'Flag', '', ''],
  ['KN', 'St. Kitts & Nevis', 'سانت كيتس ونيفيس', '🇰🇳', 17.34, -62.76, '🇰🇳', 'Flag', '', ''],
  ['LC', 'St. Lucia', 'سانت لوسيا', '🇱🇨', 13.89, -60.98, '🇱🇨', 'Flag', '', ''],
  ['MF', 'St. Martin', 'سان مارتن', '🇲🇫', 18.08, -63.05, '🇲🇫', 'Flag', '', ''],
  ['PM', 'St. Pierre & Miquelon', 'سان بيير ومكويلون', '🇵🇲', 47.04, -56.33, '🇵🇲', 'Flag', '', ''],
  ['VC', 'St. Vincent & Grenadines', 'سانت فنسنت وجزر غرينادين', '🇻🇨', 13.09, -61.34, '🇻🇨', 'Flag', '', ''],
  ['SD', 'Sudan', 'السودان', '🇸🇩', 16.33, 29.26, '🇸🇩', 'Flag', '', ''],
  ['SR', 'Suriname', 'سورينام', '🇸🇷', 4.14, -55.91, '🇸🇷', 'Flag', '', ''],
  ['SE', 'Sweden', 'السويد', '🇸🇪', 65.86, 19.02, '🇸🇪', 'Flag', '', ''],
  ['CH', 'Switzerland', 'سويسرا', '🇨🇭', 46.72, 7.46, '🇨🇭', 'Flag', '', ''],
  ['SY', 'Syria', 'سوريا', '🇸🇾', 35.01, 38.28, '🇸🇾', 'Flag', '', ''],
  ['ST', 'São Tomé & Príncipe', 'ساو تومي وبرينسيبي', '🇸🇹', 0.97, 7.02, '🇸🇹', 'Flag', '', ''],
  ['TW', 'Taiwan', 'تايوان', '🇹🇼', 23.65, 120.87, '🇹🇼', 'Flag', '', ''],
  ['TJ', 'Tajikistan', 'طاجيكستان', '🇹🇯', 38.20, 72.59, '🇹🇯', 'Flag', '', ''],
  ['TZ', 'Tanzania', 'تنزانيا', '🇹🇿', -6.05, 34.96, '🇹🇿', 'Flag', '', ''],
  ['TH', 'Thailand', 'تايلاند', '🇹🇭', 15.46, 101.07, '🇹🇭', 'Flag', '', ''],
  ['TL', 'Timor-Leste', 'تيمور - ليشتي', '🇹🇱', -8.80, 125.85, '🇹🇱', 'Flag', '', ''],
  ['TG', 'Togo', 'توغو', '🇹🇬', 8.81, 1.06, '🇹🇬', 'Flag', '', ''],
  ['TO', 'Tonga', 'تونغا', '🇹🇴', -21.21, -175.16, '🇹🇴', 'Flag', '', ''],
  ['TT', 'Trinidad & Tobago', 'ترينيداد وتوباغو', '🇹🇹', 11.00, -60.92, '🇹🇹', 'Flag', '', ''],
  ['TN', 'Tunisia', 'تونس', '🇹🇳', 33.69, 9.01, '🇹🇳', 'Flag', '', ''],
  ['TM', 'Turkmenistan', 'تركمانستان', '🇹🇲', 39.86, 58.68, '🇹🇲', 'Flag', '', ''],
  ['TC', 'Turks & Caicos Islands', 'جزر توركس وكايكوس', '🇹🇨', 21.82, -71.75, '🇹🇨', 'Flag', '', ''],
  ['TV', 'Tuvalu', 'توفالو', '🇹🇻', -8.51, 179.21, '🇹🇻', 'Flag', '', ''],
  ['VI', 'U.S. Virgin Islands', 'جزر فيرجن الأمريكية', '🇻🇮', 17.75, -64.78, '🇻🇮', 'Flag', '', ''],
  ['UG', 'Uganda', 'أوغندا', '🇺🇬', 1.97, 32.95, '🇺🇬', 'Flag', '', ''],
  ['AE', 'United Arab Emirates', 'الإمارات العربية المتحدة', '🇦🇪', 23.47, 54.55, '🇦🇪', 'Flag', '', ''],
  ['UY', 'Uruguay', 'أورغواي', '🇺🇾', -32.96, -55.97, '🇺🇾', 'Flag', '', ''],
  ['UZ', 'Uzbekistan', 'أوزبكستان', '🇺🇿', 41.69, 64.01, '🇺🇿', 'Flag', '', ''],
  ['VU', 'Vanuatu', 'فانواتو', '🇻🇺', -15.37, 166.91, '🇻🇺', 'Flag', '', ''],
  ['VA', 'Vatican City', 'الفاتيكان', '🇻🇦', 41.90, 12.45, '🇻🇦', 'Flag', '', ''],
  ['VE', 'Venezuela', 'فنزويلا', '🇻🇪', 7.18, -64.60, '🇻🇪', 'Flag', '', ''],
  ['VN', 'Vietnam', 'فيتنام', '🇻🇳', 21.72, 105.39, '🇻🇳', 'Flag', '', ''],
  ['WF', 'Wallis & Futuna', 'جزر والس وفوتونا', '🇼🇫', -14.29, -178.14, '🇼🇫', 'Flag', '', ''],
  ['EH', 'Western Sahara', 'الصحراء الغربية', '🇪🇭', 23.97, -12.63, '🇪🇭', 'Flag', '', ''],
  ['YE', 'Yemen', 'اليمن', '🇾🇪', 15.33, 45.87, '🇾🇪', 'Flag', '', ''],
  ['ZM', 'Zambia', 'زامبيا', '🇿🇲', -14.66, 26.40, '🇿🇲', 'Flag', '', ''],
  ['ZW', 'Zimbabwe', 'زيمبابوي', '🇿🇼', -18.91, 29.93, '🇿🇼', 'Flag', '', ''],
  ['AX', 'Åland Islands', 'جزر آلاند', '🇦🇽', 60.16, 19.87, '🇦🇽', 'Flag', '', ''],
];

List<Object> countryOf(String code) => kWorld.firstWhere((c) => c[0] == code, orElse: () => kWorld[0]);

/// Original, neutral riddles. answers: accepted words (lowercase).
const List<List<Object>> kRiddles = [
  ['What has keys but cannot open a door?', 'عندها مفاتيح بس مبتفتحش باب. إيه هي؟', ['piano', 'keyboard', 'بيانو', 'كيبورد', 'اورج', 'أورج']],
  ['What gets wetter the more it dries?', 'إيه اللي بيتبل أكتر كل ما ينشف؟', ['towel', 'فوطة', 'منشفة', 'فوطه']],
  ['I travel the world but stay in the corner. What am I?', 'بلف الدنيا وانا ساكن في الركن. أنا مين؟', ['stamp', 'ختم', 'طابع']],
  ['What has rivers and roads but no water or cars?', 'فيها أنهار وطرق من غير مية ولا عربيات. إيه هي؟', ['map', 'خريطة', 'خريطه']],
  ['The more you take, the more you leave behind. What are they?', 'كل ما تاخد منها أكتر، بتسيب وراك أكتر. إيه هي؟', ['steps', 'footsteps', 'step', 'خطوات', 'خطوة']],
  ['What can you catch but never throw?', 'إيه اللي تقدر تمسكه بس مش تقدر ترميه؟', ['cold', 'a cold', 'برد', 'زكام']],
  ['What has hands but cannot clap?', 'عندها ايدين بس مبتصقفش. إيه هي؟', ['clock', 'watch', 'ساعة', 'ساعه']],
];

/// Prologue and scroll 1 of "The Lost Papyrus Routes". Original text, short.
const List<List<Object>> kChapters = [
  ['Prologue: The Archive', 'الفصل صفر: الأرشيف',
    'Long ago, beside the Nile, keepers sealed seven scrolls in a quiet archive. Each scroll held a way of listening: to a stranger, a song, a map, a meal. When the river changed course, the scrolls were carried away along old trade routes. Nobody remembers where they went. Tonight, a strip of papyrus washed up at your door. It is blank, except for one word: "Begin".',
    'من زمان، على ضفة النيل، حراس قفلوا سبع لفائف في أرشيف هادي. كل لفة فيها طريقة للاستماع: لغريب، لأغنية، لخريطة، لأكلة. لما النهر غيّر مجراه، اتحملت اللفايف على طرق التجارة القديمة ومحدش فاكر راحت فين. الليلة جت ورقة بردي على بابك. فاضية، غير كلمة واحدة: "ابدأ".',
    'What do you do with the blank papyrus?', ['Write a greeting', 'Keep it safe']],
  ['Scroll 1, Chapter 1: The Keeper of your home', 'اللفة 1، الفصل 1: حارس بلدك',
    'Your home country has a keeper. Keepers do not guard treasure, they guard habits: how people say hello, what they cook when it rains, which song everyone knows. Your keeper whispers: "The first scroll opens only when someone from another country answers you." You need a friend from far away.',
    'لكل بلد حارس. الحراس مش بيحرسوا كنز، بيحرسوا عادات: إزاي الناس بتسلم، بتطبخ إيه وقت المطر، أنهي أغنية الكل يعرفها. حارس بلدك بيهمس: "اللفة الأولى مبتتفتحش غير لما حد من بلد تانية يرد عليك". محتاج صاحب من بعيد.',
    'How will you find someone far away?', ['Send a papyrus into the world', 'Ask Nilo for a hint']],
  ['Scroll 1, Chapter 2: The first reply', 'اللفة 1، الفصل 2: أول رد',
    'A papyrus crosses oceans in seconds on the map, but real replies take a little longer. While you wait, the keeper teaches you one word from another land. Words are keys. Every word you learn turns one small lock inside the archive.',
    'البردية بتعدي المحيطات في ثواني على الخريطة، بس الرد الحقيقي بياخد وقت أطول شوية. وانت مستني، الحارس بيعلمك كلمة من بلد تانية. الكلمات مفاتيح. كل كلمة تتعلمها بتفتح قفل صغير جوه الأرشيف.',
    'Which word will you learn first?', ['Hello', 'Thank you']],
  ['Scroll 1, Chapter 3: The scroll opens', 'اللفة 1، الفصل 3: اللفة بتتفتح',
    'The first scroll unrolls. It is a map with no names, only small symbols: a pyramid, a kite, a maple leaf, a sunflower. Under it, one line: "Every place on this map is somebody\'s home. Visit them kindly." Scroll 2 waits in a country you have not met yet.',
    'اللفة الأولى اتفتحت. خريطة من غير أسماء، رموز صغيرة بس: هرم، طيارة ورق، ورقة قيقب، عباد شمس. تحتها سطر: "كل مكان على الخريطة دي بيت حد. زورهم بلطف". اللفة 2 مستنية في بلد لسه متعرفتش عليها.',
    'How will you carry this scroll forward?', ['Share it with a friend', 'Keep exploring alone']],
];

/// The form your papyrus takes, by home country. Cosmetic only. Countries not listed keep the scroll.
const Map<String, String> kPapyrusForms = {
  'JP': '✈️', 'FR': '🪶', 'CA': '🍁', 'GB': '💌', 'US': '🦅', 'IT': '🍕', 'DE': '🥨', 'ES': '💃', 'BR': '⚽', 'IN': '🪔',
  'CN': '🏮', 'KR': '🌸', 'MX': '🌮', 'TR': '🧿', 'EG': '📜', 'AU': '🦘', 'NL': '🌷', 'GR': '🏛️', 'RU': '🪆', 'SA': '🌴',
};
String papyrusForm(String cc) => kPapyrusForms[cc.toUpperCase()] ?? '📜';

class Passport {
  static late SharedPreferences _p;
  static Future<void> init() async { _p = await SharedPreferences.getInstance(); }
  static String get country => _p.getString('w_country') ?? '';
  static set country(String v) => _p.setString('w_country', v);
  static int get xp => _p.getInt('w_xp') ?? 0;
  /// Reeds: earned only by real actions on this phone (sending a papyrus, posting a story, a daily visit, a solved puzzle, a finished chapter). Cosmetics only, never bought with money.
  static int get reeds => _p.getInt('w_reeds') ?? 0;
  static void addReeds(int n) => _p.setInt('w_reeds', reeds + n);
  static bool spendReeds(int n) { if (reeds < n) return false; _p.setInt('w_reeds', reeds - n); return true; }
  static List<String> get owned => _p.getStringList('w_owned') ?? [];
  static void own(String id) { final l = owned; if (!l.contains(id)) { l.add(id); _p.setStringList('w_owned', l); } }
  static String equipped(String slot) => _p.getString('w_eq_$slot') ?? '';
  static void equip(String slot, String id) => _p.setString('w_eq_$slot', id);
  static int get streak => _p.getInt('w_streak') ?? 0;
  static String get nickname => _p.getString('w_nick') ?? '';
  static set nickname(String v) => _p.setString('w_nick', v);
  static bool flag(String k, [bool d = true]) => _p.getBool('f_$k') ?? d;
  static void setFlag(String k, bool v) => _p.setBool('f_$k', v);
  static List<String> get stamps => _p.getStringList('w_stamps') ?? [];
  static int get chapter => _p.getInt('w_chapter') ?? 0;
  static String _today() { final d = DateTime.now(); return '${d.year}-${d.month}-${d.day}'; }
  static int _dayNum() => DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
  static int get startDay => _p.getInt('w_start') ?? _dayNum();
  static void addXp(int n) => _p.setInt('w_xp', xp + n);
  static void addStamp(String s) { final l = stamps; if (!l.contains(s)) { l.add(s); _p.setStringList('w_stamps', l); addXp(20); } }
  /// Call when the app opens: updates the daily streak.
  static void touch() {
    if (_p.getInt('w_start') == null) _p.setInt('w_start', _dayNum());
    final last = _p.getString('w_last') ?? '';
    if (last == _today()) return;
    final y = DateTime.now().subtract(const Duration(days: 1));
    final yd = '${y.year}-${y.month}-${y.day}';
    _p.setInt('w_streak', last == yd ? streak + 1 : 1);
    _p.setString('w_last', _today());
    addXp(5); addReeds(5);
  }
  /// Daily batch: 10 papyri to catch and 10 ink to send, renewed at 12:00 local time (checked when the app opens).
  static String _noonKey() { final d = DateTime.now().subtract(const Duration(hours: 12)); return '${d.year}-${d.month}-${d.day}'; }
  static void _refill() {
    if (_p.getString('w_noon') != _noonKey()) { _p.setString('w_noon', _noonKey()); _p.setInt('w_ink', 10); _p.setInt('w_catch', 10); }
  }
  static int get ink { _refill(); return _p.getInt('w_ink') ?? 10; }
  static int get catchesLeft { _refill(); return _p.getInt('w_catch') ?? 10; }
  static bool useInk() { if (ink <= 0) return false; _p.setInt('w_ink', ink - 1); return true; }
  static void addInk(int n) { _p.setInt('w_ink', ink + n); }
  static bool useCatch() { if (catchesLeft <= 0) return false; _p.setInt('w_catch', catchesLeft - 1); return true; }
  static bool get puzzleDone => _p.getString('w_puz') == _today();
  static void puzzleSolved() { _p.setString('w_puz', _today()); addXp(15); addReeds(5); addInk(3); addStamp('puzzle-${_today()}'); }
  static int get papyri => _p.getInt('w_sent') ?? 0;
  static void papyrusSent() { _p.setInt('w_sent', papyri + 1); addXp(10); addReeds(10); }
  /// Chapters open one per day, or faster with papyri sent.
  static int get unlocked => math.min(kChapters.length, 1 + math.max(_dayNum() - startDay, papyri));
  static void finishChapter(int i) { if (i >= chapter) { _p.setInt('w_chapter', i + 1); addStamp('chapter-$i'); addXp(25); addReeds(10); } }
}

/// Detects the country on the device. Asks for approximate (coarse) location, turns it into a country code with Android's geocoder,
/// keeps ONLY the code and drops the coordinates. Falls back to the phone's region setting. Returns '' if nothing usable.
String lastDetectSource = '';

Future<String> detectCountry({required bool allowGps}) async {
  if (allowGps) {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)).timeout(const Duration(seconds: 15));
        final pm = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(const Duration(seconds: 10));
        final cc = pm.isNotEmpty ? (pm.first.isoCountryCode ?? '') : '';
        if (cc.isNotEmpty) { lastDetectSource = 'location'; return cc.toUpperCase(); }
      }
    } catch (e, st) { Health.log(e, st); }
  }
  // Mobile network / SIM country first: it follows where the phone really is, unlike the language setting (en_US on many Egyptian phones).
  try {
    final r = await const MethodChannel('nilo/native').invokeMethod<String>('region');
    if (r != null && r.length == 2) { lastDetectSource = 'network'; return r.toUpperCase(); }
  } catch (e, st) { Health.log(e, st); }
  // No SIM (wifi-only phone or tablet): the country of the internet connection. Only your IP reaches Cloudflare's public trace page; nothing is stored.
  try {
    final t = await http.get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace')).timeout(const Duration(seconds: 4));
    final m = RegExp(r'^loc=([A-Z]{2})', multiLine: true).firstMatch(t.body);
    if (m != null) { lastDetectSource = 'ip'; return m.group(1)!; }
  } catch (e, st) { Health.log(e, st); }
  lastDetectSource = 'language';
  return PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
}

class CountryPickerPage extends StatefulWidget {
  final bool stampHome;
  const CountryPickerPage({super.key, this.stampHome = true});
  @override
  State<CountryPickerPage> createState() => _CountryPickerPageState();
}

class _CountryPickerPageState extends State<CountryPickerPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final ql = q.trim().toLowerCase();
    final list = kWorld.where((c) => ql.isEmpty || (c[1] as String).toLowerCase().contains(ql) || (c[2] as String).contains(ql) || (c[0] as String).toLowerCase() == ql).toList();
    return Scaffold(
      appBar: AppBar(title: Text(L('Choose your home country • اختار بلدك')), backgroundColor: kBg),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: L('Find your country • دوّر على بلدك')), onChanged: (v) => setState(() => q = v))),
        Expanded(child: ListView(children: [
          for (final c in list)
            ListTile(
              leading: Text(c[3] as String, style: const TextStyle(fontSize: 28)),
              title: Text(L('${c[1]} • ${c[2]}')),
              subtitle: (c[8] as String).isEmpty ? null : Text(Ui.rtl ? 'الرمز: ${c[6]} ${c[7]}' : 'Symbol: ${c[6]} ${c[7]}'),
              onTap: () {
                if (widget.stampHome) { Passport.country = c[0] as String; Passport.addStamp('home-${c[0]}'); }
                Navigator.pop(context, widget.stampHome ? true : c[0]);
              },
            ),
          if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(L('Nothing to show'), textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.all(16), child: Text(L('All countries are listed. Only your country code is saved, on this phone.'), style: const TextStyle(color: Colors.white54, fontSize: 12))),
        ])),
      ]),
    );
  }
}

/// Top card on the home screen: home world, streak, daily word, daily puzzle, chapter.
class WorldCard extends StatefulWidget {
  const WorldCard({super.key});
  @override
  State<WorldCard> createState() => _WorldCardState();
}

class _WorldCardState extends State<WorldCard> {
  Future<void> _detect() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(L('Find your country')),
      content: Text(L('Nilo can use your approximate location once to work out your country. Only the country code is saved, on this phone and in your profile. Your coordinates are not stored. The Android geocoder service turns the position into a country name, so the position is sent to it for that moment. Location can be faked, so this only reduces cheating. If you say no, Nilo uses your phone region setting instead.'), style: TextStyle(height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L('No, use phone region'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(L('Allow once'))),
      ],
    ));
    if (ok == null) return;
    final cc = await detectCountry(allowGps: ok);
    if (!mounted) return;
    if (kWorld.any((c) => c[0] == cc)) {
      Passport.country = cc; Passport.addStamp('home-$cc');
      toast(context, 'Detected: ${countryOf(cc)[3]} ${countryOf(cc)[1]}');
      setState(() {});
    } else {
      toast(context, cc.isEmpty ? 'Could not detect. Pick your country.' : 'Country $cc is not in Nilo yet. Pick the closest one.');
      await _pick();
    }
  }

  Future<void> _pick() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CountryPickerPage()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = Passport.country;
    if (code.isEmpty) {
      return _box(InkWell(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => FirstRunPage(next: const _Back()))); if (mounted) setState(() {}); }, child: Padding(padding: EdgeInsets.all(16),
        child: Row(children: [Text(L('🌍'), style: TextStyle(fontSize: 34)), SizedBox(width: 12), Expanded(child: Text(L('Nai is waiting. Begin your story\nناي مستنيك. ابدأ حكايتك'), style: TextStyle(fontSize: 16, height: 1.4))), Icon(Icons.chevron_right)]))));
    }
    final c = countryOf(code);
    return _box(Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(c[3] as String, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 10),
        Expanded(child: Text('${c[1]} world • ${c[6]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        TextButton(onPressed: _pick, child: Text(L('Change'))),
      ]),
      Text(Ui.rtl ? '🔥 سلسلة ${Passport.streak} يوم   ⭐ ${Passport.xp} نقطة   🛂 ${Passport.stamps.length} ختم   🖋 حبر ${Passport.ink}' : '🔥 ${Passport.streak} day streak   ⭐ ${Passport.xp} XP   🛂 ${Passport.stamps.length} stamps   🖋 ${Passport.ink} ink', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(avatar: Icon(Icons.today, size: 18), label: Text(L('Daily word')), onPressed: () => _word(c)),
        ActionChip(avatar: Icon(Passport.puzzleDone ? Icons.check_circle : Icons.extension, size: 18), label: Text(Passport.puzzleDone ? 'Puzzle done' : 'Daily puzzle'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PuzzlePage())); if (mounted) setState(() {}); }),
        ActionChip(avatar: Icon(Icons.auto_stories, size: 18), label: Text('${Ui.rtl ? 'حكاية' : 'Story'} ${math.min(Passport.chapter + 1, kChapters.length)}/${kChapters.length}'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage())); if (mounted) setState(() {}); }),
        ActionChip(avatar: Icon(Icons.badge_outlined, size: 18), label: Text(L('Name card')), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NameCardPage()))),
        ActionChip(avatar: Icon(Icons.flight_takeoff, size: 18), label: Text(L('Trip')), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripPage()))),
        ActionChip(avatar: Icon(Icons.badge, size: 18), label: Text(L('Passport')), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassportPage()))),
      ]),
    ])));
  }

  void _word(List<Object> home) {
    final rich = kWorld.where((c) => (c[8] as String).isNotEmpty).toList();
    final other = rich[(Passport._dayNum() + 3) % rich.length];
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(L('Word of the day')),
      content: Text(Ui.rtl ? '${other[3]} ${other[1]}\n\nمرحبا: ${other[8]}\nشكراً: ${other[9]}\n\nنصيحة: قولها لحد من هناك. الكتابة بالخط المحلي.' : '${other[3]} ${other[1]}\n\nHello: ${other[8]}\nThank you: ${other[9]}\n\nTip: say it to someone from there. Spelling is shown in the local script.', style: TextStyle(height: 1.5)),
      actions: [TextButton(onPressed: () { Passport.addStamp('word-${other[0]}'); Navigator.pop(context); setState(() {}); }, child: Text(L('Got it, +stamp')))],
    ));
  }

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFF12304D), border: Border.all(color: kGreen.withOpacity(0.6)), borderRadius: BorderRadius.circular(16)),
        child: Material(color: Colors.transparent, child: child),
      );
}

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});
  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  final c = TextEditingController();
  String msg = '';
  List<Object> get r => kRiddles[Passport._dayNum() % kRiddles.length];
  void _check() {
    final a = c.text.trim().toLowerCase();
    final ok = (r[2] as List<String>).any((x) => a == x || (a.length > 2 && a.contains(x)));
    setState(() => msg = ok ? 'Correct! +15 XP, +3 ink and a stamp.' : 'Not yet. Try again.');
    if (ok && !Passport.puzzleDone) Passport.puzzleSolved();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Daily puzzle • لغز اليوم')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text(r[0] as String, style: const TextStyle(fontSize: 20, height: 1.4)),
          const SizedBox(height: 8),
          Text(r[1] as String, style: const TextStyle(fontSize: 18, color: kGreen, height: 1.4)),
          const SizedBox(height: 16),
          if (Passport.puzzleDone) Text(L('You solved today\'s puzzle. Come back tomorrow.'), style: TextStyle(color: Colors.white70)) else ...[
            TextField(controller: c, decoration: InputDecoration(border: OutlineInputBorder(), hintText: L('Your answer (English or Arabic)'))),
            const SizedBox(height: 10),
            FilledButton(onPressed: _check, child: Text(L('Check'))),
          ],
          const SizedBox(height: 10),
          Text(L(msg)),
        ]),
      );
}

class StoryPage extends StatefulWidget {
  const StoryPage({super.key});
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  static const gold = Color(0xFFE0B04A);
  @override
  Widget build(BuildContext context) {
    final un = Passport.unlocked;
    final done = Passport.chapter.clamp(0, kChapters.length);
    final cur = done < un ? done : -1;
    String en(int i) { final t = kChapters[i][0] as String; final k = t.indexOf(': '); return k < 0 ? t : t.substring(k + 2); }
    String ar(int i) { final t = kChapters[i][1] as String; final k = t.indexOf(': '); return k < 0 ? t : t.substring(k + 2); }
    Future<void> open(int i) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterPage(i: i))); if (mounted) setState(() {}); }
    return Scaffold(
      appBar: AppBar(title: Text(L('حكاية • الطرق الضائعة')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Text(L('حكاية واحدة للعالم كله. فصل جديد كل يوم، أو أسرع لما تبعت بردية.'), style: TextStyle(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: done / kChapters.length, minHeight: 6, color: gold, backgroundColor: Colors.white12)),
        const SizedBox(height: 4),
        Text('$done / ${kChapters.length}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 14),
        if (cur >= 0)
          GestureDetector(
            onTap: () => open(cur),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6EACB), Color(0xFFE2CB93)]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L('📜  الفصل الجاي • Next'), style: TextStyle(color: Color(0xFF8A6B2F), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(ar(cur), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF3B2A18), height: 1.3)),
                Text(en(cur), style: const TextStyle(fontSize: 14, color: Color(0xFF5B4630))),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Chip(label: Text(L('اقرأ • Read')), backgroundColor: Color(0xFFE0B04A))),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        for (var i = 0; i < kChapters.length; i++)
          if (i != cur)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFF10294A), borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: i < done ? gold : Colors.white10, child: i < done ? const Icon(Icons.check, color: Colors.black87) : (i < un ? Text('${i}', style: const TextStyle(color: gold)) : const Icon(Icons.lock, size: 18, color: Colors.white38))),
                title: Text(ar(i), style: TextStyle(fontWeight: FontWeight.w700, color: i < un ? Colors.white : Colors.white38)),
                subtitle: Text(i < un ? en(i) : 'يفتح بكرة، أو ابعت بردية', style: TextStyle(fontSize: 12, color: i < un ? Colors.white60 : Colors.white30)),
                onTap: i < un ? () => open(i) : null,
              ),
            ),
        const SizedBox(height: 6),
        Text(L('الترجمة الآلية ممكن تغلط.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}

class ChapterPage extends StatelessWidget {
  final int i;
  const ChapterPage({super.key, required this.i});
  @override
  Widget build(BuildContext context) {
    final c = kChapters[i];
    return Scaffold(
      appBar: AppBar(title: Text(c[0] as String, style: const TextStyle(fontSize: 15)), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Directionality(textDirection: TextDirection.ltr, child: Text(c[2] as String, style: const TextStyle(fontSize: 17, height: 1.65, color: Color(0xFF3B2A18), fontFamily: 'serif'))),
            const Divider(color: Color(0xFF9B7B4B)),
            Directionality(textDirection: TextDirection.rtl, child: Text(c[3] as String, style: const TextStyle(fontSize: 17, height: 1.8, color: Color(0xFF3B2A18)))),
          ]),
        ),
        const SizedBox(height: 20),
        Text(c[4] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final o in c[5] as List<String>)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: FilledButton(onPressed: () { Passport.finishChapter(i); toast(context, 'Chapter done. +stamp, +XP'); Navigator.pop(context); }, child: Text(o))),
      ]),
    );
  }
}

class PassportPage extends StatelessWidget {
  const PassportPage({super.key});
  static const gold = Color(0xFFE0B04A);
  @override
  Widget build(BuildContext context) {
    final s = Passport.stamps.where((x) => !x.startsWith('trip-')).toList();
    final countries = <String>{for (final x in s) if (x.startsWith('word-') || x.startsWith('home-')) x.substring(x.indexOf('-') + 1)};
    final trust = math.min(100, 20 + Passport.streak * 3 + Passport.papyri * 2);
    Widget tile(String icon, String v, String l) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF12304F), border: Border.all(color: gold.withOpacity(.5)), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(icon, style: const TextStyle(fontSize: 20)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: gold)), Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white70))]),
      ),
    );
    final ach = <List<Object>>[
      ['🔥', 'Streak 3 days', Passport.streak >= 3],
      ['📜', 'First papyrus', Passport.papyri >= 1],
      ['🌍', '3 countries explored', countries.length >= 3],
      ['✍️', '10 papyri', Passport.papyri >= 10],
      ['🏅', '7-day streak', Passport.streak >= 7],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(L('Passport • الباسبور')), backgroundColor: kBg, actions: [
        IconButton(tooltip: L('Tools'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ToolsPage())), icon: Icon(Icons.apps)),
        IconButton(tooltip: L('Settings'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())), icon: Icon(Icons.settings)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _cover(),
        const SizedBox(height: 12),
        _dataPage(countries.length),
        const SizedBox(height: 10),
        Row(children: [tile('🔥', '${Passport.streak}', 'Streak'), tile('🛡️', '$trust', 'Trust score'), tile('📜', '${Passport.papyri}', 'Papyri sent'), tile('🌍', '${countries.length}', 'Countries explored')]),
        Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: () => showShareCard(context), icon: const Icon(Icons.ios_share, size: 18), label: Text(L('Share my card')))),
        Padding(padding: EdgeInsets.fromLTRB(4, 2, 4, 0), child: Text(L('Trust score is a local number from your own streak and papyri. It is not verified by anyone.'), style: TextStyle(fontSize: 11, color: Colors.white38))),
        const SizedBox(height: 14),
        Text(L('Daily scroll • لفافة اليوم'), style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(12)),
          child: Text(Ui.rtl ? 'الحبر المتبقي النهارده: ${Passport.ink}/10. امسك برديات، ابعت واحدة، حافظ على السلسلة. الحبر بيتجدد الساعة ١٢:٠٠.' : 'Ink left today: ${Passport.ink}/10. Catch papyri, send one, keep your streak. Ink refills at 12:00.', style: TextStyle(color: Color(0xFF5B4630))),
        ),
        const SizedBox(height: 14),
        Text(L('Achievements • إنجازات'), style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in ach) Opacity(opacity: a[2] == true ? 1 : .35, child: Chip(avatar: Text(a[0] as String), label: Text(a[1] as String))),
        ]),
        const SizedBox(height: 14),
        Text(L('Stamps • أختام'), style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            if (s.isEmpty) Text(L('No stamps yet. Pick a country, solve the daily puzzle, learn a word, or send a papyrus.'), style: TextStyle(color: Color(0xFF5B4630))),
            Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < s.length; i++) _stamp(s[i], i)]),
          ]),
        ),
        const SizedBox(height: 14),
        Text(L('Stored on this phone only. Stamps are for fun.'), style: TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
    );
  }
  Widget _cover() => Container(
    height: 170,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16406B), Color(0xFF0B2542)]),
      border: Border.all(color: gold, width: 2.5), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: gold.withOpacity(.5)), borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(L('𓂀'), style: TextStyle(fontSize: 44, color: gold)),
        SizedBox(height: 4),
        Text(L('NILO'), style: TextStyle(fontSize: 26, letterSpacing: 10, color: gold, fontWeight: FontWeight.w800)),
        Text(L('TRAVEL PASSPORT'), style: TextStyle(fontSize: 13, letterSpacing: 4, color: gold)),
        Text(L('جواز سفر نيلو'), style: TextStyle(fontSize: 15, color: gold)),
      ]),
    ),
  );

  Widget _dataPage(int nCountries) {
    const ink = Color(0xFF3B2F1E);
    final nick = Passport.nickname.isEmpty ? 'TRAVELLER' : Passport.nickname.toUpperCase();
    final c = Passport.country.isEmpty ? null : countryOf(Passport.country);
    final start = DateTime(2026, 1, 1).add(Duration(days: Passport.startDay));
    const mo = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final issued = '${start.day.toString().padLeft(2, '0')} ${mo[start.month - 1]} ${start.year}';
    final no = 'NL${(Passport.nickname.hashCode.abs() % 9000000 + 1000000)}';
    String mrz(String t) => t.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '<').padRight(30, '<').substring(0, 30);
    Widget f(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, color: Color(0xFF8A7650), letterSpacing: 1)), Text(v, style: const TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w700))]));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6EACB), Color(0xFFE9D7AA)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB89A55), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(L('PASSPORT • جواز'), style: TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFF8A7650))), Text(L('NILO'), style: TextStyle(fontSize: 11, letterSpacing: 3, color: Color(0xFF8A7650), fontWeight: FontWeight.w800))]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 90, height: 112,
            decoration: BoxDecoration(color: const Color(0xFFD8C690), border: Border.all(color: const Color(0xFFB89A55)), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(c == null ? '𓂀' : '${c[3]}', style: const TextStyle(fontSize: 46))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            f('NAME / الاسم', nick),
            f('COUNTRY / البلد', c == null ? 'NOT SET' : '${c[1]}'.toUpperCase()),
            f('DATE OF ISSUE', issued),
            f('PASSPORT NO.', no),
          ])),
        ]),
        const SizedBox(height: 6),
        Text('${mrz('P<NIL<<$nick')}\n${mrz('$no<${Passport.xp}XP<${Passport.streak}D<$nCountries')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: ink, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(L('Fun travel passport inside the Nilo app. Not a government document.'), style: TextStyle(fontSize: 9, color: Color(0xFF8A7650))),
      ]),
    );
  }

  Widget _stamp(String x, int i) {
    final col = [const Color(0xFF9B2C2C), const Color(0xFF1E4E8C), const Color(0xFF2C6B3F)][i % 3];
    final parts = _label(x).split(' ');
    final icon = parts.first;
    final name = parts.skip(1).join(' ');
    return Transform.rotate(
      angle: ((i * 7) % 11 - 5) * 0.06,
      child: Container(
        width: 92, height: 92, padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: i % 4 == 3 ? BoxShape.rectangle : BoxShape.circle, borderRadius: i % 4 == 3 ? BorderRadius.circular(8) : null, border: Border.all(color: col.withOpacity(.85), width: 3)),
        child: Container(
          decoration: BoxDecoration(shape: i % 4 == 3 ? BoxShape.rectangle : BoxShape.circle, borderRadius: i % 4 == 3 ? BorderRadius.circular(6) : null, border: Border.all(color: col.withOpacity(.7), width: 1)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.w800)),
            Text(L('NILO'), style: TextStyle(fontSize: 8, letterSpacing: 2, color: col.withOpacity(.8))),
          ]),
        ),
      ),
    );
  }

  static String _label(String x) {
    if (x.startsWith('home-')) return '🏠 ${countryOf(x.substring(5))[1]}';
    if (x.startsWith('word-')) return '💬 ${countryOf(x.substring(5))[1]}';
    if (x.startsWith('chapter-')) return '📖 Chapter ${int.parse(x.substring(8)) + 1}';
    if (x.startsWith('trip-')) return '📜 ${countryOf(x.substring(5))[1]}';
    return '🧩 Puzzle';
  }
}

/// Animated world-map trip of a papyrus. Cosmetic animation: it flies to a random country, the real reader is whoever catches it.
class PapyrusTripPage extends StatefulWidget {
  const PapyrusTripPage({super.key});
  @override
  State<PapyrusTripPage> createState() => _PapyrusTripPageState();
}

class _PapyrusTripPageState extends State<PapyrusTripPage> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..forward();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  @override
  void initState() {
    super.initState();
    Passport.papyrusSent();
    _a.addListener(() { if (_a.value > 0.97 && mounted) setState(() {}); });
  }
  @override
  void dispose() { _a.dispose(); _spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('رحلة بردييتك • Your papyrus')), backgroundColor: kBg),
        body: Column(children: [
          Expanded(child: RepaintBoundary(child: AnimatedBuilder(animation: Listenable.merge([_a, _spin]), builder: (_, __) => CustomPaint(size: Size.infinite, painter: GlobePainter(_a.value, _spin.value))))),
          Padding(padding: const EdgeInsets.all(16), child: Text(
            _a.value < 0.45 ? '📜 بتبحر في النيل • Sailing down the Nile' : (_a.value < 0.97 ? '🌍 بتطلع للبحر • Drifting out to sea' : 'بردييتك في البحر. هتوصل لحد حقيقي يلاقيها.\nAdrift. It lands with a real person who catches it.'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5))),
          Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(L('Real map outlines (Natural Earth, public domain). The route is an animation: we do not know who will catch it or where they live. When someone replies, you will see it in your inbox.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white54))),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(L('Done'))),
          const SizedBox(height: 16),
        ]),
      );
}

/// Animated background: deep gradient, moving Nile waves and drifting gold dust. Pure Flutter, no assets.
class NileBackground extends StatefulWidget {
  const NileBackground({super.key});
  @override
  State<NileBackground> createState() => _NileBackgroundState();
}

class _NileBackgroundState extends State<NileBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(size: Size.infinite, painter: _BgPainter(_c.value)))),
      );
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final h = DateTime.now().hour;
    final night = h >= 19 || h < 5;
    final dusk = (h >= 17 && h < 19) || (h >= 5 && h < 7);
    final cols = night
        ? const [Color(0xFF050E1A), Color(0xFF0A1B30), Color(0xFF0E2A45)]
        : dusk
            ? const [Color(0xFF2A2548), Color(0xFF7A4A55), Color(0xFFB87A4B)]
            : const [Color(0xFF1B4F7A), Color(0xFF2E7BA6), Color(0xFF5BA6C4)];
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: cols).createShader(rect));
    if (night) {
      final star = Paint()..color = Colors.white.withOpacity(0.55);
      for (var i = 0; i < 40; i++) {
        final tw = 0.4 + 0.6 * ((math.sin(t * 2 * math.pi * 2 + i) + 1) / 2);
        canvas.drawCircle(Offset((i * 37 % 100) / 100 * s.width, (i * 61 % 100) / 100 * s.height * 0.55), 0.8 + (i % 3) * 0.4, star..color = Colors.white.withOpacity(0.5 * tw));
      }
      canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.1), 18, Paint()..color = const Color(0xFFF3E9C6));
    } else {
      canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.045), dusk ? 30 : 24, Paint()..color = (dusk ? const Color(0xFFFFB066) : const Color(0xFFFFE9A8)).withOpacity(0.9));
    }
    final tau = 2 * math.pi;
    for (var i = 0; i < 3; i++) {
      final base = s.height * (0.80 + i * 0.07);
      final amp = 14.0 + i * 5;
      final path = Path()..moveTo(0, s.height);
      for (var x = 0.0; x <= s.width; x += 8) {
        path.lineTo(x, base + math.sin((x / s.width * 2 + t * (i.isEven ? 1 : -1)) * tau) * amp);
      }
      path..lineTo(s.width, s.height)..close();
      canvas.drawPath(path, Paint()..color = Color.fromRGBO(30 + i * 15, 90 + i * 20, 130 + i * 15, 0.22));
    }
    final dust = Paint()..color = const Color(0x33D9A441);
    for (var i = 0; i < 24; i++) {
      final px = (i * 97 % 100) / 100 * s.width;
      final py = ((i * 53 % 100) / 100 + t * (0.15 + (i % 5) * 0.03)) % 1.0 * s.height * 0.8;
      canvas.drawCircle(Offset(px + math.sin(t * tau + i) * 10, py), 1.2 + (i % 3) * 0.6, dust);
    }
  }
  @override
  bool shouldRepaint(_BgPainter o) => o.t != t;
}

/// Home tile with gradient, glow icon, press scale and haptic.
class NiloTile extends StatefulWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const NiloTile({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  State<NiloTile> createState() => _NiloTileState();
}

class _NiloTileState extends State<NiloTile> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
        child: AnimatedScale(
          scale: down ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF173A5E), Color(0xFF0F2A47)]),
              border: Border.all(color: kGreen.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGreen.withOpacity(0.16), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.25), blurRadius: 12)]),
                child: Icon(widget.icon, color: kGreen, size: 22),
              ),
              const SizedBox(height: 8),
              Text(L(widget.title), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(L(widget.sub), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.25)),
            ]),
          ),
        ),
      );
}

/// Nai, the small guide: gold circle with a quill, speech bubble.
class NaiSays extends StatelessWidget {
  final String en, ar;
  const NaiSays({super.key, required this.en, required this.ar});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFB8860B)]), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 14)]),
          child: Text(L('🪶'), style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF12304D), border: Border.all(color: kGreen.withOpacity(0.5)), borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L('Nai • ناي'), style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 4),
            Text(en, style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Text(ar, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
          ]),
        )),
      ]);
}

/// First-run story: a papyrus drifts down the Nile, Nai asks where it found you, then nickname, 18+ and a first stamp.
class FirstRunPage extends StatefulWidget {
  final Widget next;
  const FirstRunPage({super.key, required this.next});
  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  bool busy = true, adult = false;
  String code = '';
  final nick = TextEditingController();
  final nickF = FocusNode();
  @override
  void initState() { super.initState(); _auto(); }
  @override
  void dispose() { _a.dispose(); nick.dispose(); nickF.dispose(); super.dispose(); }

  /// Quiet detection from the mobile network / SIM, no permission and no location.
  Future<void> _auto() async {
    final cc = await detectCountry(allowGps: false);
    if (!mounted) return;
    setState(() { busy = false; if (kWorld.any((c) => c[0] == cc)) code = cc; });
  }

  Future<void> _gps() async {
    setState(() => busy = true);
    final cc = await detectCountry(allowGps: true);
    if (!mounted) return;
    setState(() { busy = false; if (kWorld.any((c) => c[0] == cc)) code = cc; });
    if (!kWorld.any((c) => c[0] == cc)) toast(context, 'Could not detect. Tap the flag to choose.');
  }

  Future<void> _choose() async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CountryPickerPage()));
    if (!mounted) return;
    if (r == true && Passport.country.isNotEmpty) setState(() => code = Passport.country);
  }

  void _rules() => showModalBottomSheet(context: context, backgroundColor: Color(0xFF12304D), builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Rules • القواعد'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kGreen)),
          SizedBox(height: 10),
          Text(L('• 18+ only. Self-declared: Nilo cannot check your age.\n• Text only. No links, phone numbers or social handles.\n• Never send money or share bank or ID details.\n• Meet only in public places and tell a friend.\n• Report and block anyone who makes you uncomfortable.\n• Machine translation can be wrong.'), style: TextStyle(height: 1.6)),
          SizedBox(height: 10),
          Text(L('٠ للكبار ١٨+ فقط  ٠ نص بس، من غير لينكات أو أرقام  ٠ متبعتش فلوس  ٠ قابل حد في مكان عام  ٠ بلّغ واحظر أي حد يضايقك'), style: TextStyle(height: 1.6, color: Colors.white70)),
        ]),
      ));

  /// Same checks as the passport button, then the email sign-up screen (the passport data stays on this phone and is saved to the account).
  void _signup() {
    if (code.isEmpty) { toast(context, 'Tap the flag to choose your country'); return; }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthPage(next: widget.next, startSignUp: true, fromFirstRun: true, cc: code)));
  }

  void _login() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthPage(next: widget.next, fromFirstRun: true)));

  void _finish() {
    if (code.isEmpty) { toast(context, 'Tap the flag to choose your country'); return; }
    if (nick.text.trim().length < 2) { toast(context, 'Choose a nickname (2 to 20 letters)'); nickF.requestFocus(); return; }
    if (!adult) { toast(context, 'Please confirm you are 18 or older'); return; }
    Passport.country = code;
    Passport.addStamp('home-$code');
    Passport.nickname = nick.text.trim();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.next));
  }

  @override
  Widget build(BuildContext context) {
    final has = code.isNotEmpty;
    final c = has ? countryOf(code) : null;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        const Positioned.fill(child: NileBackground()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(animation: _a, builder: (_, __) => Transform.translate(offset: Offset(0, math.sin(_a.value * math.pi) * 6), child: Text(L('📜'), style: TextStyle(fontSize: 46)))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _choose,
                  child: busy
                      ? const SizedBox(height: 96, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(children: [
                          Text(has ? c![3] as String : '🌍', style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 4),
                          Text(has ? 'Welcome from ${c![1]}' : 'Choose your country', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(has ? 'أهلا بيك من ${c![2]}' : 'اختار بلدك', style: const TextStyle(fontSize: 15, color: Colors.white70)),
                          const SizedBox(height: 2),
                          if (has) Text(L(lastDetectSource == 'network' ? 'Detected from your mobile network • من شبكة الموبايل' : lastDetectSource == 'ip' ? 'Detected from your internet connection • من الإنترنت' : lastDetectSource == 'location' ? 'Confirmed with your location • اتأكدت بالموقع' : 'Guessed from your phone language • من لغة الموبايل'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                          Text(L('Not right? Tap to change • مش صح؟ اضغط'), style: TextStyle(fontSize: 12, color: kGreen)),
                        ]),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: nick, focusNode: nickF, maxLength: 20, textAlign: TextAlign.center,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))), hintText: L('Nickname, not your real name • اسم مستعار'), counterText: ''),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Checkbox(value: adult, onChanged: (v) => setState(() => adult = v ?? false), visualDensity: VisualDensity.compact),
                  Expanded(child: Text.rich(TextSpan(style: const TextStyle(fontSize: 13), children: [
                    const TextSpan(text: 'I am 18+ and accept the '),
                    WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: GestureDetector(onTap: _rules, child: Text(L('rules'), style: TextStyle(fontSize: 13, color: kGreen, decoration: TextDecoration.underline)))),
                  ]))),
                ]),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _finish, style: FilledButton.styleFrom(shape: StadiumBorder()), child: Text(L('Continue as guest • كمل كضيف'), style: TextStyle(fontSize: 16)))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _signup, child: Text(L('Create account • حساب جديد'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(onPressed: _login, child: Text(L('I have an account • عندي حساب'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)))),
                ]),
                Text(L('The nickname and 18+ box are only for guests. With an account you set them on the next screen.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                TextButton(onPressed: busy ? null : _gps, child: Text(L('Confirm with my location once (country only, nothing saved) • أكد بالموقع مرة'), style: TextStyle(fontSize: 12, color: Colors.white54))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Pops back to the home screen after the first-run story when opened from the card.
class _Back extends StatelessWidget {
  const _Back();
  @override
  Widget build(BuildContext context) { WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) Navigator.of(context).pop(); }); return const Scaffold(); }
}
