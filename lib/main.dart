import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // בקשת הרשאות לקבלת התראות פוש (חובה לאייפון, מומלץ לאנדרואיד)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('הרשאת התראות התקבלה: ${settings.authorizationStatus}');

  // טיפול בהתראות כאשר האפליקציה פתוחה ברקע / בחזית
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('התקבלה התראה כשהאפליקציה פתוחה: ${message.notification?.title}');
  });

  runApp(const SportiadaApp());
}

class SportiadaApp extends StatelessWidget {
  const SportiadaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportiada 2026',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: const Color(0xFF1E293B).withOpacity(0.85),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
      },
    );
  }
}

// ווידג'ט עזר עוטף לתמונת הרקע
class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const AppBackgroundWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.25),
          ),
        ),
        child,
      ],
    );
  }
}

// 1. מסך התחברות
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('נא להכניס מספר טלפון')),
      );
      return;
    }

    if (phone == '0524643510') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ManagerPortalScreen()),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('phone', isEqualTo: phone)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('מספר טלפון לא זוהה במערכת הניהול')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();
      final staffName = staffData['name'] ?? '';

      // שמירת ה־FCM Token של המכשיר בענן תחת איש הצוות לצורך שליחת התראות פוש
      try {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection('staff')
              .doc(staffDoc.id)
              .update({'fcmToken': fcmToken});
        }
      } catch (e) {
        print('שגיאה בשמירת טוקן התראות: $e');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VolunteerPortalScreen(phoneNumber: phone, staffName: staffName),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בהתחברות: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SPORTIADA 2026',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
                  ),
                  const SizedBox(height: 10),
                  const Text('הכנס את מספר הטלפון שלך לכניסה למערכת', style: TextStyle(color: Color(0xFF94A3B8))),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '0500000000',
                      filled: true,
                      fillColor: const Color(0xFF0B1220),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('כניסה למערכת', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2. פורטל מתנדב בשטח
class VolunteerPortalScreen extends StatelessWidget {
  final String phoneNumber;
  final String staffName;

  const VolunteerPortalScreen({Key? key, required this.phoneNumber, required this.staffName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staff')
            .where('phone', isEqualTo: phoneNumber)
            .snapshots(),
        builder: (context, staffSnapshot) {
          if (!staffSnapshot.hasData) {
            return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator()));
          }

          final docs = staffSnapshot.data!.docs;
          if (docs.isEmpty) {
            return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text('המשתמש הוסר ממערכת הניהול')));
          }

          final staffData = docs.first.data() as Map<String, dynamic>;
          
          dynamic rawKit;
          staffData.forEach((key, value) {
            final lowerKey = key.toLowerCase();
            if (lowerKey == 'kitid' || lowerKey == 'kit' || lowerKey == 'kitnumber' || lowerKey == 'kit_id') {
              rawKit = value;
            }
          });

          final kitId = (rawKit != null && rawKit.toString().trim().isNotEmpty) 
              ? rawKit.toString() 
              : 'לא הוקצתה ערכה';

          return VolunteerDateSelectionScreen(phoneNumber: phoneNumber, staffName: staffName, kitId: kitId);
        },
      ),
    );
  }
}

class VolunteerDateSelectionScreen extends StatefulWidget {
  final String phoneNumber;
  final String staffName;
  final String kitId;

  const VolunteerDateSelectionScreen({Key? key, required this.phoneNumber, required this.staffName, required this.kitId}) : super(key: key);

  @override
  _VolunteerDateSelectionScreenState createState() => _VolunteerDateSelectionScreenState();
}

class _VolunteerDateSelectionScreenState extends State<VolunteerDateSelectionScreen> {
  String? selectedDate;

  @override
  Widget build(BuildContext context) {
    if (selectedDate == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('שלום, ${widget.staffName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
            )
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('config').snapshots(),
          builder: (context, configSnapshot) {
            if (!configSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final configData = configSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final publishedDatesMap = configData['publishedDates'] as Map<String, dynamic>? ?? {};

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('assign')
                  .where('staffName', isEqualTo: widget.staffName)
                  .snapshots(),
              builder: (context, assignSnapshot) {
                if (!assignSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final assignDocs = assignSnapshot.data!.docs;
                List<String> activeDates = [];

                for (var doc in assignDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = data['date'] as String? ?? '';
                  if (date.isNotEmpty && publishedDatesMap[date] == true) {
                    if (!activeDates.contains(date)) {
                      activeDates.add(date);
                    }
                  }
                }

                if (activeDates.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'אין עדיין שיבוצים משודרים עבורך לתאריכים הקרובים.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('בחר תאריך לצפייה בפרטי האבטחה:', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: activeDates.length,
                          itemBuilder: (context, index) {
                            String date = activeDates[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedDate = date;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '📅 $date',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    }

    return VolunteerDayAssignmentsScreen(
      staffName: widget.staffName,
      selectedDate: selectedDate!,
      kitId: widget.kitId,
      onBack: () => setState(() => selectedDate = null),
    );
  }
}

// 3. מסך מציג רשימת שיבוצים ממוינת בסדר עולה לפי שעת ההתחלה
class VolunteerDayAssignmentsScreen extends StatelessWidget {
  final String staffName;
  final String selectedDate;
  final String kitId;
  final VoidCallback onBack;

  const VolunteerDayAssignmentsScreen({
    Key? key,
    required this.staffName,
    required this.selectedDate,
    required this.kitId,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('שיבוצים לתאריך: $selectedDate'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('assign')
              .where('staffName', isEqualTo: staffName)
              .where('date', isEqualTo: selectedDate)
              .snapshots(),
          builder: (context, assignSnapshot) {
            if (!assignSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = assignSnapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('אין פרטי שיבוץ לתאריך זה'));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').snapshots(),
              builder: (context, postsSnapshot) {
                List<Map<String, dynamic>> parsedAssignments = [];

                for (var doc in docs) {
                  final assignData = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final postName = assignData['postName'] ?? 'לא מצוין';

                  String dutyStart = assignData['start'] ?? assignData['startTime'] ?? assignData['from'] ?? '';
                  String dutyEnd = assignData['end'] ?? assignData['endTime'] ?? assignData['to'] ?? '';

                  if (dutyStart.isEmpty || dutyEnd.isEmpty) {
                    if (postsSnapshot.hasData) {
                      for (var postDoc in postsSnapshot.data!.docs) {
                        final postData = postDoc.data() as Map<String, dynamic>;
                        final pName = postData['name'] ?? '';
                        final pLoc = postData['location'] ?? '';
                        final displayName = pLoc.isNotEmpty ? '$pName - $pLoc' : pName;

                        if (postName == displayName || postName == pName || postName.contains(pLoc) || pLoc.contains(postName)) {
                          dutyStart = dutyStart.isEmpty ? (postData['start'] ?? '07:00') : dutyStart;
                          dutyEnd = dutyEnd.isEmpty ? (postData['end'] ?? '15:00') : dutyEnd;
                          break;
                        }
                      }
                    }
                  }

                  if (dutyStart.isEmpty) dutyStart = '07:00';
                  if (dutyEnd.isEmpty) dutyEnd = '15:00';

                  parsedAssignments.add({
                    'docId': docId,
                    'assignData': assignData,
                    'postName': postName,
                    'dutyStart': dutyStart,
                    'dutyEnd': dutyEnd,
                  });
                }

                // מיון הרשימה בסדר עולה לפי שעת ההתחלה (מהמוקדם למאוחר)
                parsedAssignments.sort((a, b) => a['dutyStart'].compareTo(b['dutyStart']));

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: parsedAssignments.length,
                  itemBuilder: (context, index) {
                    final item = parsedAssignments[index];
                    final docId = item['docId'];
                    final assignData = item['assignData'] as Map<String, dynamic>;
                    final postName = item['postName'];
                    final dutyStart = item['dutyStart'];
                    final dutyEnd = item['dutyEnd'];

                    final arrivalVal = assignData['actualArrival'] ?? assignData['start'] ?? assignData['startTime'];
                    final endVal = assignData['actualEnd'] ?? assignData['end'] ?? assignData['endTime'];

                    final hasArrived = arrivalVal != null && arrivalVal.toString().trim().isNotEmpty;
                    final hasEnded = endVal != null && endVal.toString().trim().isNotEmpty;

                    return Card(
                      color: const Color(0xFF1E293B).withOpacity(0.85),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('ענף / עמדה: $postName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                            const SizedBox(height: 8),
                            Text('שעות פעילות עמדה: $dutyStart - $dutyEnd', style: const TextStyle(color: Color(0xFF94A3B8))),
                            const SizedBox(height: 8),
                            Text('מספר ערכת חירום: $kitId', style: const TextStyle(color: Color(0xFF94A3B8))),
                            const SizedBox(height: 16),
                            
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasArrived ? Colors.grey[700] : const Color(0xFF166534), 
                                padding: const EdgeInsets.all(12),
                              ),
                              onPressed: hasArrived ? null : () => _reportActualTime(docId, true, context),
                              icon: Icon(hasArrived ? Icons.check_circle : Icons.check_circle_outline),
                              label: Text(
                                hasArrived ? 'הוצגה הגעה בשעה: $arrivalVal' : 'דיווח הגעה לעמדה',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 10),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasEnded ? Colors.grey[700] : const Color(0xFF7F1D1D), 
                                padding: const EdgeInsets.all(12),
                              ),
                              onPressed: hasEnded ? null : () => _reportActualTime(docId, false, context),
                              icon: Icon(hasEnded ? Icons.stop : Icons.stop_circle_outlined),
                              label: Text(
                                hasEnded ? 'הוצג סיום בשעה: $endVal' : 'דיווח סיום משמרת',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.all(14)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientReportScreen()));
            },
            icon: const Icon(Icons.medical_services),
            label: const Text('הוספת מטופל חדש', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _reportActualTime(String docId, bool isStart, BuildContext context) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      if (isStart) {
        await FirebaseFirestore.instance.collection('assign').doc(docId).update({
          'actualArrival': timeStr,
          'start': timeStr,
          'startTime': timeStr,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('דווחה שעת הגעה: $timeStr')),
        );
      } else {
        await FirebaseFirestore.instance.collection('assign').doc(docId).update({
          'actualEnd': timeStr,
          'end': timeStr,
          'endTime': timeStr,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('דווחה שעת סיום משמרת: $timeStr')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בשמירת הדיווח לענן: $e')),
      );
    }
  }
}

// 4. טופס דיווח מטופל מחובר ל־Firebase
class PatientReportScreen extends StatefulWidget {
  const PatientReportScreen({Key? key}) : super(key: key);

  @override
  _PatientReportScreenState createState() => _PatientReportScreenState();
}

class _PatientReportScreenState extends State<PatientReportScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _shirtNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sportBranchController = TextEditingController();
  final _injuryDescController = TextEditingController();
  
  final _pulseController = TextEditingController();
  String _pulseType = 'סדיר';
  
  final _bpController = TextEditingController();
  final _sugarController = TextEditingController();
  final _tempController = TextEditingController();
  final _treatmentDescController = TextEditingController();
  
  String _endStatus = 'לא פונה - המשיך בתחרות';
  bool _isLoading = false;

  Future<void> _submitPatient() async {
    if (_nameController.text.isEmpty || _shirtNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('נא למלא לפחות את שם המטופל ומספר החולצה')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('patients').add({
        'name': _nameController.text.trim(),
        'idNumber': _idController.text.trim(),
        'shirtNumber': _shirtNumberController.text.trim(),
        'phone': _phoneController.text.trim(),
        'sportBranch': _sportBranchController.text.trim(),
        'injuryDescription': _injuryDescController.text.trim(),
        'pulse': _pulseController.text.trim(),
        'pulseType': _pulseType,
        'bloodPressure': _bpController.text.trim(),
        'sugar': _sugarController.text.trim(),
        'bodyTemperature': _tempController.text.trim(),
        'treatmentDescription': _treatmentDescController.text.trim(),
        'endStatus': _endStatus,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תיק המטופל נשמר בהצלחה בענן!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בשמירה לענן: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('טופס דיווח מטופל - שטח'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('פרטי זיהוי ואירוע', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 12),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'שם מטופל', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _idController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'מספר ת.ז', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _shirtNumberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "מס' חולצה", filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "מס' טלפון", filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _sportBranchController, decoration: const InputDecoration(labelText: 'שם ענף', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _injuryDescController, maxLines: 2, decoration: const InputDecoration(labelText: 'תיאור פציעה / מחלה', filled: true, fillColor: Color(0xFF1E293B))),
              
              const SizedBox(height: 24),
              const Text('מדדים חיוניים', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(controller: _pulseController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'דופק', filled: true, fillColor: Color(0xFF1E293B))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _pulseType,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(filled: true, fillColor: Color(0xFF1E293B), border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'סדיר', child: Text('סדיר')),
                        DropdownMenuItem(value: 'לא סדיר', child: Text('לא סדיר')),
                      ],
                      onChanged: (val) => setState(() => _pulseType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _bpController, decoration: const InputDecoration(labelText: 'לחץ דם', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _sugarController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'סוכר', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              TextField(controller: _tempController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'חום גוף', filled: true, fillColor: Color(0xFF1E293B))),

              const SizedBox(height: 24),
              const Text('טיפול וסטטוס סיום', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 12),
              TextField(controller: _treatmentDescController, maxLines: 3, decoration: const InputDecoration(labelText: 'תיאור טיפול', filled: true, fillColor: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _endStatus,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(labelText: 'סטטוס סיום', filled: true, fillColor: Color(0xFF1E293B), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'לא פונה - המשיך בתחרות', child: Text('לא פונה - המשיך בתחרות')),
                  DropdownMenuItem(value: 'לא פונה - סיים את התחרות', child: Text('לא פונה - סיים את התחרות')),
                  DropdownMenuItem(value: 'פונה - אמב\' רגיל', child: Text('פונה - אמב\' רגיל')),
                  DropdownMenuItem(value: 'פונה - אמב\' אט"ן', child: Text('פונה - אמב\' אט"ן')),
                ],
                onChanged: (val) => setState(() => _endStatus = val!),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), padding: const EdgeInsets.all(14)),
                  onPressed: _isLoading ? null : _submitPatient,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('שמור דיווח מטופל בענן', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 5. מסך מנהל / מוקד מחובר לענן בזמן אמת
class ManagerPortalScreen extends StatelessWidget {
  const ManagerPortalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('מערכת ניהול - מוקד ספורטיאדה'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
              tooltip: 'התנתק',
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('patients')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('שגיאה בטעינת הנתונים: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'אין דיווחים מהשטח כרגע',
                  style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final docId = docs[index].id;

                final name = data['name'] ?? 'ללא שם';
                final idNum = data['idNumber'] ?? 'לא מצוין';
                final shirtNum = data['shirtNumber'] ?? '';
                final phone = data['phone'] ?? 'לא מצוין';
                final branch = data['sportBranch'] ?? 'לא מצוין';
                final injury = data['injuryDescription'] ?? 'אין תיאור';
                final status = data['endStatus'] ?? '';
                final treatment = data['treatmentDescription'] ?? '';
                final pulse = data['pulse'] ?? '';
                final pulseType = data['pulseType'] ?? '';
                final bp = data['bloodPressure'] ?? '';
                final sugar = data['sugar'] ?? '';
                final temp = data['bodyTemperature'] ?? '';

                Color statusColor = Colors.blue;
                if (status.contains('אט"ן')) {
                  statusColor = Colors.red;
                } else if (status.contains('רגיל')) {
                  statusColor = Colors.orange;
                } else if (status.contains('המשיך')) {
                  statusColor = Colors.green;
                }

                return Card(
                  color: const Color(0xFF1E293B).withOpacity(0.85),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$name (חולצה: $shirtNum)',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('patients').doc(docId).delete();
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF334155)),
                        Text('ת.ז: $idNum | טלפון: $phone', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('ענף ספורט: $branch', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('תיאור פציעה: $injury', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        const Text('מדדים חיוניים:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                        Text('• דופק: $pulse ($pulseType) | לחץ דם: $bp', style: const TextStyle(color: Colors.white60)),
                        Text('• סוכר: $sugar | חום גוף: $temp', style: const TextStyle(color: Colors.white60)),
                        if (treatment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('טיפול שניתן: $treatment', style: const TextStyle(color: Colors.white60)),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            'סטטוס: $status',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}