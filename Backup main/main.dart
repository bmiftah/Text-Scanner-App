import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ============================================================
// ALIBABA CLOUD QWEN CONFIGURATION
// ============================================================
const String API_BASE_URL = 'https://ws-qw4bl2cm5x4dv10v.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1';
const String API_KEY = 'sk-ws-H.HXMYLX.wR34.MEUCIQDJ-U9M5grWzFUXssyu9YtGlkY8COW2Co8G323ZxvpoaQIgSc9XkzZKAfoONF1rdxMFbqSUbQupH6cOxcKxbqUWDdY';
const String MODEL_NAME = 'qwen3.7-plus';
// ============================================================

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await [Permission.camera, Permission.photos].request();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Scanner',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(); // For ML Kit fallback
  
  bool _isProcessing = false;
  bool _showCamera = true;
  String _errorMessage = '';
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _hasResults = false;
  int _languageIndex = 0;

  final Map<int, Map<String, String>> _uiStrings = {
    0: { // English
      'appName': 'Text Scanner', 'instruction': 'Take a photo or select an image to extract text',
      'tip': 'Align card within frame, ensure good lighting', 'scanText': 'SCAN TEXT',
      'selectFile': 'SELECT FROM FILE', 'close': 'CLOSE', 'scanAnother': 'SCAN ANOTHER',
      'saveToCsv': 'SAVE TO CSV', 'openWebsite': 'OPEN WEBSITE', 'feedback': 'FEEDBACK',
      'contact': 'CONTACT', 'by': 'By Miftah B.', 'contactDev': 'Contact Developer',
      'processing': 'Extracting information, please wait...', 'noTextDetected': 'No text detected. Please ensure good lighting.',
      'apiFailed': 'API connection failed. Using fallback OCR.', 'fallbackUsed': 'Used basic OCR (English only)',
      'name': 'Name', 'email': 'Email', 'phone': 'Phone', 'website': 'Website', 'notes': 'Notes',
      'namePlaceholder': 'Name not detected', 'emailPlaceholder': 'Email not detected',
      'phonePlaceholder': 'Phone not detected', 'websitePlaceholder': 'Website not detected',
      'notesPlaceholder': 'Notes not detected', 'editTitle': 'Contact Information',
      'saveSuccess': 'Contact saved successfully!', 'closeApp': 'Close App', 'thankYou': 'Thank you for using Text Scanner!',
      'cancel': 'CANCEL', 'gotIt': 'GOT IT', 'helpTitle': 'How to Use',
      'helpContent': '1. Tap "SCAN TEXT" to take a photo\n2. Or tap "SELECT FROM FILE"\n3. Information will be extracted automatically\n4. Edit any fields as needed\n5. Tap "SAVE TO CSV" to export',
      'wechat': 'WeChat', 'whatsapp': 'WhatsApp', 'missingInfo': 'Missing Information',
      'pleaseFillIn': 'Please fill in:', 'ok': 'OK', 'sendFeedback': 'Send Feedback',
      'feedbackHint': 'Enter your feedback...', 'submit': 'SUBMIT', 'thankYouFeedback': 'Thank you for your feedback!',
      'validEmail': 'Please enter a valid email address', 'noWebsite': 'No website to open', 'noPhone': 'No phone number to call',
    },
    1: { // Chinese
      'appName': '文字扫描仪', 'instruction': '拍照或选择图片来提取文字',
      'tip': '将卡片放在框内拍摄，确保光线充足', 'scanText': '拍照扫描', 'selectFile': '从相册选择',
      'close': '关闭', 'scanAnother': '扫描另一张', 'saveToCsv': '保存到CSV', 'openWebsite': '打开网站',
      'feedback': '反馈', 'contact': '联系', 'by': '作者：Miftah B.', 'contactDev': '联系开发者',
      'processing': '正在提取信息，请稍候...', 'noTextDetected': '未检测到文字。请确保光线充足。',
      'apiFailed': 'API连接失败。使用基础OCR。', 'fallbackUsed': '使用基础OCR（仅英文）',
      'name': '姓名', 'email': '邮箱', 'phone': '电话', 'website': '网站', 'notes': '备注',
      'namePlaceholder': '未检测到姓名', 'emailPlaceholder': '未检测到邮箱', 'phonePlaceholder': '未检测到电话',
      'websitePlaceholder': '未检测到网站', 'notesPlaceholder': '未检测到备注', 'editTitle': '联系人信息',
      'saveSuccess': '联系人保存成功！', 'closeApp': '关闭应用', 'thankYou': '感谢使用文字扫描仪！',
      'cancel': '取消', 'gotIt': '知道了', 'helpTitle': '使用说明',
      'helpContent': '1. 点击"拍照扫描"\n2. 或点击"从相册选择"\n3. 自动提取信息\n4. 编辑字段\n5. 点击"保存到CSV"导出',
      'wechat': '微信', 'whatsapp': 'WhatsApp', 'missingInfo': '缺少信息',
      'pleaseFillIn': '请填写：', 'ok': '确定', 'sendFeedback': '发送反馈',
      'feedbackHint': '请输入您的反馈...', 'submit': '提交', 'thankYouFeedback': '感谢您的反馈！',
      'validEmail': '请输入有效的电子邮件地址', 'noWebsite': '没有网站可打开', 'noPhone': '没有电话号码可拨打',
    },
    2: { // Amharic
      'appName': 'ጽሁፍ ማውጫ', 'instruction': 'ፎቶ ያንሱ ወይም ምስል ይምረጡ',
      'tip': 'ካርዱን በክፈፉ ውስጥ ያስቀምጡ፣ ብርሃን ያረጋግጡ', 'scanText': 'ፎቶ ያንሱ', 'selectFile': 'ከፋይል ይምረጡ',
      'close': 'ይዝጉ', 'scanAnother': 'ሌላ ፎቶ', 'saveToCsv': 'ወደ ፋይል አስቀምጥ', 'openWebsite': 'ድረ ገጽ ክፈት',
      'feedback': 'አስተያየት', 'contact': 'አግኙን', 'by': 'በሚፍታህ ቢ.', 'contactDev': 'አዘጋጁን ያግኙ',
      'processing': 'መረጃ እየወጣ ነው...', 'noTextDetected': 'ምንም ጽሁፍ አልተገኘም። ብርሃን ያረጋግጡ',
      'apiFailed': 'ግንኙነት አልተሳካም። መሰረታዊ ኦሲአር በመጠቀም', 'fallbackUsed': 'መሰረታዊ ኦሲአር ጥቅም ላይ ውሏል',
      'name': 'ስም', 'email': 'ኢሜይል', 'phone': 'ስልክ', 'website': 'ድረ ገጽ', 'notes': 'ማስታወሻ',
      'namePlaceholder': 'ስም አልተገኘም', 'emailPlaceholder': 'ኢሜይል አልተገኘም',
      'phonePlaceholder': 'ስልክ አልተገኘም', 'websitePlaceholder': 'ድረ ገጽ አልተገኘም',
      'notesPlaceholder': 'ማስታወሻ አልተገኘም', 'editTitle': 'የእውቂያ መረጃ',
      'saveSuccess': 'እውቂያ ተቀምጧል!', 'closeApp': 'መተግበሪያ ዝጋ', 'thankYou': 'እናመሰግናለን!',
      'cancel': 'ሰርዝ', 'gotIt': 'ገባኝ', 'helpTitle': 'አጠቃቀም',
      'helpContent': '1. "ፎቶ ያንሱ" ይጫኑ\n2. ወይም "ከፋይል ይምረጡ"\n3. መረጃ ይወጣል\n4. ያርትዑ\n5. "ወደ ፋይል አስቀምጥ" ይጫኑ',
      'wechat': 'ዊቻት', 'whatsapp': 'ዋትሳፕ', 'missingInfo': 'የጎደለ መረጃ',
      'pleaseFillIn': 'እባክዎ ይሙሉ፦', 'ok': 'እሺ', 'sendFeedback': 'አስተያየት ላክ',
      'feedbackHint': 'አስተያየትዎን ያስገቡ...', 'submit': 'ላክ', 'thankYouFeedback': 'እናመሰግናለን!',
      'validEmail': 'እባክዎ ትክክለኛ ኢሜይል ያስገቡ', 'noWebsite': 'ምንም ድረ ገጽ የለም', 'noPhone': 'ምንም ስልክ ቁጥር የለም',
    },
    3: { // Arabic
      'appName': 'ماسح النص', 'instruction': 'التقط صورة أو اختر صورة لاستخراج النص',
      'tip': 'ضع البطاقة داخل الإطار، تأكد من الإضاءة الجيدة', 'scanText': 'التقاط صورة', 'selectFile': 'اختر من الملف',
      'close': 'إغلاق', 'scanAnother': 'مسح آخر', 'saveToCsv': 'حفظ إلى CSV', 'openWebsite': 'فتح الموقع',
      'feedback': 'ملاحظات', 'contact': 'اتصل', 'by': 'بواسطة Miftah B.', 'contactDev': 'اتصل بالمطور',
      'processing': 'جاري استخراج المعلومات...', 'noTextDetected': 'لم يتم اكتشاف نص. تأكد من الإضاءة',
      'apiFailed': 'فشل الاتصال. استخدام OCR الأساسي', 'fallbackUsed': 'تم استخدام OCR الأساسي (إنجليزي فقط)',
      'name': 'الاسم', 'email': 'البريد', 'phone': 'الهاتف', 'website': 'الموقع', 'notes': 'ملاحظات',
      'namePlaceholder': 'الاسم غير موجود', 'emailPlaceholder': 'البريد غير موجود',
      'phonePlaceholder': 'الهاتف غير موجود', 'websitePlaceholder': 'الموقع غير موجود',
      'notesPlaceholder': 'ملاحظات غير موجودة', 'editTitle': 'معلومات الاتصال',
      'saveSuccess': 'تم حفظ جهة الاتصال!', 'closeApp': 'إغلاق التطبيق', 'thankYou': 'شكرا لاستخدامك!',
      'cancel': 'إلغاء', 'gotIt': 'فهمت', 'helpTitle': 'كيفية الاستخدام',
      'helpContent': '1. اضغط "التقاط صورة"\n2. أو "اختر من الملف"\n3. يتم استخراج المعلومات\n4. حرر الحقول\n5. اضغط "حفظ إلى CSV"',
      'wechat': 'ويشات', 'whatsapp': 'واتساب', 'missingInfo': 'معلومات مفقودة',
      'pleaseFillIn': 'يرجى ملء:', 'ok': 'موافق', 'sendFeedback': 'إرسال ملاحظات',
      'feedbackHint': 'أدخل ملاحظاتك...', 'submit': 'إرسال', 'thankYouFeedback': 'شكرا لملاحظاتك!',
      'validEmail': 'يرجى إدخال بريد صالح', 'noWebsite': 'لا يوجد موقع', 'noPhone': 'لا يوجد رقم هاتف',
    },
    4: { // Russian
      'appName': 'Текстовый сканер', 'instruction': 'Сделайте фото или выберите изображение',
      'tip': 'Поместите карту в рамку, обеспечьте хорошее освещение', 'scanText': 'Сделать фото', 'selectFile': 'Выбрать файл',
      'close': 'Закрыть', 'scanAnother': 'Новое сканирование', 'saveToCsv': 'Сохранить в CSV', 'openWebsite': 'Открыть сайт',
      'feedback': 'Отзыв', 'contact': 'Контакты', 'by': 'Miftah B.', 'contactDev': 'Связаться',
      'processing': 'Извлечение информации...', 'noTextDetected': 'Текст не обнаружен. Проверьте освещение',
      'apiFailed': 'Ошибка соединения. Использование базового OCR', 'fallbackUsed': 'Использован базовый OCR (только английский)',
      'name': 'Имя', 'email': 'Email', 'phone': 'Телефон', 'website': 'Сайт', 'notes': 'Заметки',
      'namePlaceholder': 'Имя не найдено', 'emailPlaceholder': 'Email не найден',
      'phonePlaceholder': 'Телефон не найден', 'websitePlaceholder': 'Сайт не найден',
      'notesPlaceholder': 'Заметки не найдены', 'editTitle': 'Контактная информация',
      'saveSuccess': 'Контакт сохранен!', 'closeApp': 'Закрыть приложение', 'thankYou': 'Спасибо за использование!',
      'cancel': 'Отмена', 'gotIt': 'Понял', 'helpTitle': 'Как использовать',
      'helpContent': '1. Нажмите "Сделать фото"\n2. Или "Выбрать файл"\n3. Информация извлекается\n4. Редактируйте поля\n5. Нажмите "Сохранить в CSV"',
      'wechat': 'WeChat', 'whatsapp': 'WhatsApp', 'missingInfo': 'Отсутствует информация',
      'pleaseFillIn': 'Пожалуйста, заполните:', 'ok': 'ОК', 'sendFeedback': 'Отправить отзыв',
      'feedbackHint': 'Введите ваш отзыв...', 'submit': 'ОТПРАВИТЬ', 'thankYouFeedback': 'Спасибо за отзыв!',
      'validEmail': 'Введите действительный email', 'noWebsite': 'Нет сайта', 'noPhone': 'Нет телефона',
    },
    5: { // French
      'appName': 'Scanner Texte', 'instruction': 'Prenez une photo ou sélectionnez une image',
      'tip': 'Alignez la carte dans le cadre, bon éclairage', 'scanText': 'SCAN TEXTE', 'selectFile': 'CHOISIR FICHIER',
      'close': 'FERMER', 'scanAnother': 'AUTRE SCAN', 'saveToCsv': 'ENREGISTRER CSV', 'openWebsite': 'OUVRIR SITE',
      'feedback': 'AVIS', 'contact': 'CONTACT', 'by': 'Par Miftah B.', 'contactDev': 'Contacter',
      'processing': 'Extraction en cours...', 'noTextDetected': 'Aucun texte détecté. Vérifiez l\'éclairage',
      'apiFailed': 'Échec connexion. Utilisation OCR basique', 'fallbackUsed': 'OCR basique utilisé (anglais uniquement)',
      'name': 'Nom', 'email': 'Email', 'phone': 'Téléphone', 'website': 'Site web', 'notes': 'Notes',
      'namePlaceholder': 'Nom non détecté', 'emailPlaceholder': 'Email non détecté',
      'phonePlaceholder': 'Téléphone non détecté', 'websitePlaceholder': 'Site non détecté',
      'notesPlaceholder': 'Notes non détectées', 'editTitle': 'Informations Contact',
      'saveSuccess': 'Contact enregistré!', 'closeApp': 'Fermer', 'thankYou': 'Merci d\'utiliser Scanner Texte!',
      'cancel': 'ANNULER', 'gotIt': 'COMPRIS', 'helpTitle': 'Comment utiliser',
      'helpContent': '1. Appuyez sur "SCAN TEXTE"\n2. Ou "CHOISIR FICHIER"\n3. Informations extraites\n4. Modifiez\n5. Appuyez sur "ENREGISTRER CSV"',
      'wechat': 'WeChat', 'whatsapp': 'WhatsApp', 'missingInfo': 'Info manquante',
      'pleaseFillIn': 'Veuillez remplir:', 'ok': 'OK', 'sendFeedback': 'Envoyer avis',
      'feedbackHint': 'Entrez votre avis...', 'submit': 'ENVOYER', 'thankYouFeedback': 'Merci pour votre avis!',
      'validEmail': 'Email valide requis', 'noWebsite': 'Pas de site', 'noPhone': 'Pas de téléphone',
    },
    6: { // Bengali
      'appName': 'টেক্সট স্ক্যানার', 'instruction': 'টেক্সট বের করতে ছবি তুলুন বা ছবি নির্বাচন করুন',
      'tip': 'ফ্রেমের ভিতরে কার্ড রাখুন, ভালো আলো নিশ্চিত করুন', 'scanText': 'ছবি তুলুন', 'selectFile': 'ফাইল নির্বাচন',
      'close': 'বন্ধ', 'scanAnother': 'আরেকটি স্ক্যান', 'saveToCsv': 'সিএসভি সেভ', 'openWebsite': 'ওয়েবসাইট খুলুন',
      'feedback': 'মতামত', 'contact': 'যোগাযোগ', 'by': 'মিফতাহ বি.', 'contactDev': 'ডেভেলপারকে যোগাযোগ',
      'processing': 'তথ্য বের করা হচ্ছে...', 'noTextDetected': 'কোনো টেক্সট পাওয়া যায়নি। আলো পরীক্ষা করুন',
      'apiFailed': 'সংযোগ ব্যর্থ। বেসিক ওসিআর ব্যবহার', 'fallbackUsed': 'বেসিক ওসিআর ব্যবহার (শুধু ইংরেজি)',
      'name': 'নাম', 'email': 'ইমেইল', 'phone': 'ফোন', 'website': 'ওয়েবসাইট', 'notes': 'নোট',
      'namePlaceholder': 'নাম পাওয়া যায়নি', 'emailPlaceholder': 'ইমেইল পাওয়া যায়নি',
      'phonePlaceholder': 'ফোন পাওয়া যায়নি', 'websitePlaceholder': 'ওয়েবসাইট পাওয়া যায়নি',
      'notesPlaceholder': 'নোট পাওয়া যায়নি', 'editTitle': 'যোগাযোগের তথ্য',
      'saveSuccess': 'যোগাযোগ সংরক্ষিত!', 'closeApp': 'অ্যাপ বন্ধ', 'thankYou': 'টেক্সট স্ক্যানার ব্যবহারের জন্য ধন্যবাদ!',
      'cancel': 'বাতিল', 'gotIt': 'বুঝেছি', 'helpTitle': 'কিভাবে ব্যবহার করবেন',
      'helpContent': '1. "ছবি তুলুন" চাপুন\n2. অথবা "ফাইল নির্বাচন"\n3. তথ্য বের হবে\n4. সম্পাদনা করুন\n5. "সিএসভি সেভ" চাপুন',
      'wechat': 'উইচ্যাট', 'whatsapp': 'হোয়াটসঅ্যাপ', 'missingInfo': 'অনুপস্থিত তথ্য',
      'pleaseFillIn': 'অনুগ্রহ করে পূরণ করুন:', 'ok': 'ঠিক আছে', 'sendFeedback': 'মতামত পাঠান',
      'feedbackHint': 'আপনার মতামত দিন...', 'submit': 'পাঠান', 'thankYouFeedback': 'আপনার মতামতের জন্য ধন্যবাদ!',
      'validEmail': 'সঠিক ইমেইল দিন', 'noWebsite': 'কোনো ওয়েবসাইট নেই', 'noPhone': 'কোনো ফোন নম্বর নেই',
    },
  };

  String getText(String key) {
    return _uiStrings[_languageIndex]?[key] ?? _uiStrings[0]![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
    _setupControllers();
  }

  void _setupControllers() {
    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _websiteController.addListener(() => setState(() {}));
    _notesController.addListener(() => setState(() {}));
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) return;
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      await _controller?.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Camera error: $e");
    }
  }

  Future<void> _captureFromCamera() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile picture = await _controller!.takePicture();
      await _processImage(File(picture.path));
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  // ML Kit Fallback - extracts text when API fails
  Future<String> _fallbackToMLKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      print('ML Kit fallback error: $e');
      return '';
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _showCamera = false;
      _errorMessage = '';
      _hasResults = true;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final prompt = """Extract the following information from this business card or document:
- Person's full name
- Email address (ONLY THE FIRST ONE if multiple)
- Phone number
- Website URL (if present on the card)
- A short note (company name and brief description)

Return ONLY valid JSON in this exact format, nothing else:
{"name":"","email":"","phone":"","website":"","notes":""}
If a field is missing, use empty string. Do NOT infer website from email. Only use website if explicitly written on the card.""";
                                                                                                         
      final response = await _callVisionAPI(base64Image, prompt);
      
      if (response != null) {
        String email = response['email'] ?? '';
        if (email.contains(',')) {
          email = email.split(',')[0].trim();
        }
        if (email.contains(' ') && email.contains('@')) {
          final parts = email.split(' ');
          for (var part in parts) {
            if (part.contains('@')) {
              email = part;
              break;
            }
          }
        }
        
        setState(() {
          _nameController.text = response['name'] ?? '';
          _emailController.text = email;
          _phoneController.text = response['phone'] ?? '';
          _websiteController.text = response['website'] ?? '';
          _notesController.text = response['notes'] ?? '';
          _isProcessing = false;
          _errorMessage = '';
        });
      } else {
        // API FAILED - Use ML Kit fallback
        final fallbackText = await _fallbackToMLKit(imageFile);
        
        if (fallbackText.isNotEmpty) {
          // Simple extraction from fallback text
          setState(() {
            _nameController.text = _extractNameFromText(fallbackText);
            _emailController.text = _extractEmailFromText(fallbackText);
            _phoneController.text = _extractPhoneFromText(fallbackText);
            _websiteController.text = '';
            _notesController.text = fallbackText.length > 100 
                ? fallbackText.substring(0, 100) 
                : fallbackText;
            _isProcessing = false;
            _errorMessage = getText('fallbackUsed');
          });
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = getText('noTextDetected');
            _nameController.text = '';
            _emailController.text = '';
            _phoneController.text = '';
            _websiteController.text = '';
            _notesController.text = '';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = getText('noTextDetected');
      });
    }
  }

  // Helper methods for ML Kit fallback
  String _extractEmailFromText(String text) {
    final RegExp emailRegExp = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final match = emailRegExp.firstMatch(text);
    return match?.group(0) ?? '';
  }

  String _extractPhoneFromText(String text) {
    final RegExp phoneRegExp = RegExp(r'[\+]?[0-9][0-9\s\-]{7,15}');
    final match = phoneRegExp.firstMatch(text);
    return match?.group(0)?.trim() ?? '';
  }

  String _extractNameFromText(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.length >= 3 && line.length <= 30 && !line.contains('@') && !RegExp(r'[0-9]').hasMatch(line)) {
        return line;
      }
    }
    return '';
  }

  Future<Map<String, dynamic>?> _callVisionAPI(String base64Image, String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $API_KEY',
        },
        body: jsonEncode({
          "model": MODEL_NAME,
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful assistant that extracts structured data. Always return valid JSON only. No markdown, no extra text."
            },
            {
              "role": "user",
              "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
              ]
            }
          ],
          "temperature": 0.0,
          "max_tokens": 500,
          "enable_thinking": false,
        }),
      ).timeout(const Duration(seconds: 15));
      
      print('API Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        try {
          String cleanContent = content.trim();
          if (cleanContent.startsWith('```json')) cleanContent = cleanContent.substring(7);
          if (cleanContent.startsWith('```')) cleanContent = cleanContent.substring(3);
          if (cleanContent.endsWith('```')) cleanContent = cleanContent.substring(0, cleanContent.length - 3);
          cleanContent = cleanContent.trim();
          return jsonDecode(cleanContent);
        } catch (e) {
          print('JSON parse error: $e');
          return null;
        }
      } else {
        print('API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Network error: $e');
      return null;
    }
  }

  void _resetScanner() {
    setState(() {
      _showCamera = true;
      _hasResults = false;
      _errorMessage = '';
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _websiteController.clear();
      _notesController.clear();
    });
  }

  void _closeApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(getText('closeApp')),
        content: Text(getText('thankYou')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(getText('thankYou')), duration: const Duration(seconds: 2)),
              );
              Future.delayed(const Duration(milliseconds: 500), () => SystemNavigator.pop());
            },
            child: Text(getText('close')),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String field) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$field copied')));
  }

  Future<void> _composeEmail(String email) async {
    if (email.isEmpty) return;
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) await launchUrl(emailUri);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('noPhone'))));
      return;
    }
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWebsite() async {
    final String website = _websiteController.text.trim();
    if (website.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('noWebsite'))));
      return;
    }
    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open website')));
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(getText('helpTitle')),
        content: Text(getText('helpContent')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('gotIt')))],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(getText('contactDev')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: '+8613804325010'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied')));
              },
              child: const Text('📞 +8613804325010', style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'miftahbedru@gmail.com'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied')));
              },
              child: const Text('📧 miftahbedru@gmail.com', style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.chat, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '13804325010'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WeChat ID copied')));
                  },
                  child: Text('${getText('wechat')}: 13804325010', style: const TextStyle(color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.chat, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '13804325010'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number copied')));
                  },
                  child: Text('${getText('whatsapp')}: 13804325010', style: const TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('close')))],
      ),
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(getText('sendFeedback')),
        content: TextField(
          controller: feedbackController,
          decoration: InputDecoration(hintText: getText('feedbackHint')),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('thankYouFeedback'))));
            },
            child: Text(getText('submit')),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) => RegExp(r'^[\w\.%\+\-]+@[\w\-]+(?:\.[\w\-]+)+$').hasMatch(email);

  Future<void> _saveToCSV() async {
    String email = _emailController.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('validEmail'))));
      return;
    }
    await _writeToCSV({
      'name': _nameController.text.trim(),
      'email': email,
      'phone': _phoneController.text.trim(),
      'website': _websiteController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }

  Future<void> _writeToCSV(Map<String, String> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/contacts.csv';
      final File file = File(filePath);
      String csvContent = await file.exists() ? await file.readAsString() : "Name,Email,Phone,Website,Notes\n";
      if (!csvContent.endsWith('\n')) csvContent += '\n';
      csvContent += '"${_escapeCSV(data['name'] ?? '')}","${_escapeCSV(data['email'] ?? '')}","${_escapeCSV(data['phone'] ?? '')}","${_escapeCSV(data['website'] ?? '')}","${_escapeCSV(data['notes'] ?? '')}"\n';
      await file.writeAsString(csvContent);
      _showSuccessDialog(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Success'),
        content: Text(getText('saveSuccess')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('close'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles([XFile(filePath)], text: 'Contact Export');
            },
            child: const Text('📤 SHARE/OPEN'),
          ),
        ],
      ),
    );
  }

  String _escapeCSV(String input) => input.isEmpty ? '' : input.replaceAll('"', '""');

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          title: _languageIndex == 2
              ? const Text('ጽሁፍ ማውጫ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))
              : Text(getText('appName'), style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          toolbarHeight: 70,
          actions: [
            PopupMenuButton<int>(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language, size: 18),
                  const SizedBox(width: 4),
                  Text(_languageIndex == 0 ? 'EN' : (_languageIndex == 1 ? '中文' : (_languageIndex == 2 ? 'አማ' : (_languageIndex == 3 ? 'عربي' : (_languageIndex == 4 ? 'RU' : (_languageIndex == 5 ? 'FR' : 'BN')))))),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ]),
              ),
              onSelected: (int index) => setState(() => _languageIndex = index),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 0, child: Text('English')),
                const PopupMenuItem(value: 1, child: Text('中文')),
                const PopupMenuItem(value: 2, child: Text('አማርኛ')),
                const PopupMenuItem(value: 3, child: Text('العربية')),
                const PopupMenuItem(value: 4, child: Text('Русский')),
                const PopupMenuItem(value: 5, child: Text('Français')),
                const PopupMenuItem(value: 6, child: Text('বাংলা')),
              ],
            ),
            IconButton(icon: const Icon(Icons.help_outline), onPressed: _showHelpDialog),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade300, width: 2), borderRadius: BorderRadius.circular(20)),
              child: _showCamera ? _buildCameraView() : (_isProcessing ? _buildProcessingView() : _buildEditableFormView()),
            ),
          ),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(getText('by'), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                GestureDetector(onTap: _showContactDialog, child: Text(getText('contactDev'), style: TextStyle(fontSize: 11, color: Colors.green[600]))),
                OutlinedButton.icon(
                  onPressed: _closeApp,
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(getText('close'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyan), foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: Text(getText('instruction'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _controller != null && _controller!.value.isInitialized
                  ? CameraPreview(_controller!)
                  : Container(color: Colors.grey[900], child: const Center(child: Text('Initializing camera...'))),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange[700]),
              const SizedBox(width: 6),
              Expanded(child: Text(getText('tip'), style: TextStyle(fontSize: 12, color: Colors.grey[700]), textAlign: TextAlign.center)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              if (_errorMessage.isNotEmpty && _showCamera)
                Container(padding: const EdgeInsets.all(6), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(_errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _captureFromCamera,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(getText('scanText'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(getText('selectFile'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search, size: 48, color: Colors.blue), SizedBox(height: 16),
      Text('Extracting information...', style: TextStyle(fontSize: 14)), SizedBox(height: 20), CircularProgressIndicator(),
    ]),
  );

  Widget _buildEditableFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetScanner, icon: const Icon(Icons.camera_alt, size: 18),
            label: Text('📷 ${getText('scanAnother')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage.isNotEmpty)
          Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]), const SizedBox(width: 8),
              Expanded(child: Text(_errorMessage, style: TextStyle(fontSize: 12, color: Colors.orange[800]))),
            ]),
          ),
        _buildEditableField(label: getText('name'), controller: _nameController, icon: Icons.person, placeholder: getText('namePlaceholder')),
        const SizedBox(height: 8),
        _buildEditableField(label: getText('email'), controller: _emailController, icon: Icons.email, placeholder: getText('emailPlaceholder'), isEmail: true),
        const SizedBox(height: 8),
        _buildEditableField(label: getText('phone'), controller: _phoneController, icon: Icons.phone, placeholder: getText('phonePlaceholder'), isPhone: true),
        const SizedBox(height: 8),
        _buildEditableFieldWithAction(label: getText('website'), controller: _websiteController, icon: Icons.link, placeholder: getText('websitePlaceholder'),
          actionIcon: Icons.open_in_browser, actionLabel: getText('openWebsite'), onAction: _openWebsite),
        const SizedBox(height: 8),
        _buildEditableField(label: getText('notes'), controller: _notesController, icon: Icons.note, placeholder: getText('notesPlaceholder'), maxLines: 2),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveToCSV, icon: const Icon(Icons.save, size: 18),
            label: Text(getText('saveToCsv'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _showFeedbackDialog, icon: const Icon(Icons.feedback, size: 16), label: Text(getText('feedback'), style: const TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _showContactDialog, icon: const Icon(Icons.contact_mail, size: 16), label: Text(getText('contact'), style: const TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)))),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildEditableField({required String label, required TextEditingController controller, required IconData icon, required String placeholder, bool isEmail = false, bool isPhone = false, int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.blue), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          TextField(controller: controller, style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(hintText: placeholder, hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 4)),
            keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : null), maxLines: maxLines,
          ),
        ])),
        if (isEmail && controller.text.isNotEmpty) IconButton(icon: const Icon(Icons.email, size: 16), onPressed: () => _composeEmail(controller.text)),
        if (isPhone && controller.text.isNotEmpty) IconButton(icon: const Icon(Icons.call, size: 16), onPressed: () => _makePhoneCall(controller.text)),
        if (controller.text.isNotEmpty) IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () => _copyToClipboard(controller.text, label)),
      ]),
    );
  }

  Widget _buildEditableFieldWithAction({required String label, required TextEditingController controller, required IconData icon, required String placeholder,
    required IconData actionIcon, required String actionLabel, required VoidCallback onAction, int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.blue), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          TextField(controller: controller, style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(hintText: placeholder, hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 4)),
            maxLines: maxLines,
          ),
        ])),
        if (controller.text.isNotEmpty) IconButton(icon: Icon(actionIcon, size: 16), onPressed: onAction, tooltip: actionLabel),
        if (controller.text.isNotEmpty) IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () => _copyToClipboard(controller.text, label)),
      ]),
    );
  }
}