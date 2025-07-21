import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';  
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> { 

  // Variables para el contador reactivo
  Map<String, bool> _weeklyReadings = {};
  StreamSubscription<DatabaseEvent>? _readingsSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _discoveredDevices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  QualifiedCharacteristic? _glucoseCharacteristic;
  bool _isScanning = false;

  String? _currentMeasurementType;
  
  // Información del usuario
  String _userName = "Usuario";
  String _userLastName = "";
  Map<String, dynamic> _userData = {};
  
  // Datos de glucosa
  String _glucoseValue = "-";
  String _dateTime = "";
  
  // Estado de conexión Bluetooth
  bool _isBluetoothConnected = false;
  bool _isBluetoothConnecting = false;
  
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLatestMeasurement();
    _updateDateTime();
    _loadWeeklyReadings(); // Cargar mediciones semanales

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _readingsSubscription?.cancel(); // Cancelar suscripción
    super.dispose();
  }

  // Método para cargar las mediciones semanales
  Future<void> _loadWeeklyReadings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Calcular fecha de inicio de semana (último domingo)
    final now = DateTime.now();
    final startOfWeek = _getStartOfWeek(now);
    final startTimestamp = startOfWeek.millisecondsSinceEpoch;

    // Escuchar cambios en las lecturas de la semana actual
    _readingsSubscription = _database
        .child('users/${user.uid}/readings')
        .orderByChild('timestamp')
        .startAt(startTimestamp)
        .onValue
        .listen((DatabaseEvent event) {
      _processWeeklyReadings(event.snapshot);
    });
  }

  // Método para obtener el inicio de la semana (domingo)
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromSunday = date.weekday % 7;
    final startOfWeek = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromSunday));
    return startOfWeek;
  }

  // Procesar las mediciones de la semana
  void _processWeeklyReadings(DataSnapshot snapshot) {
    final Map<String, bool> weeklyData = {};
    
    // Inicializar todos los días como false
    for (int i = 0; i < 7; i++) {
      final date = _getStartOfWeek(DateTime.now()).add(Duration(days: i));
      final dateKey = _formatDateKey(date);
      weeklyData[dateKey] = false;
    }

    if (snapshot.exists && snapshot.value != null) {
      final readings = Map<String, dynamic>.from(snapshot.value as Map);
      
      readings.forEach((key, value) {
        final reading = Map<String, dynamic>.from(value);
        final timestamp = reading['timestamp'] as int?;
        
        if (timestamp != null) {
          final readingDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateKey = _formatDateKey(readingDate);
          
          // Marcar el día como completado si hay al menos una medición
          if (weeklyData.containsKey(dateKey)) {
            weeklyData[dateKey] = true;
          }
        }
      });
    }

    // Actualizar el estado
    if (mounted) {
      setState(() {
        _weeklyReadings = weeklyData;
      });
    }
  }

  // Formatear fecha como clave (YYYY-MM-DD)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Obtener el estado de medición para un día específico
  bool _hasReadingForDay(int dayIndex) {
    final date = _getStartOfWeek(DateTime.now()).add(Duration(days: dayIndex));
    final dateKey = _formatDateKey(date);
    return _weeklyReadings[dateKey] ?? false;
  }

  // Contar mediciones completadas en la semana
  int _getCompletedReadingsCount() {
    return _weeklyReadings.values.where((hasReading) => hasReading).length;
  }

  // Realizar medición con tipo específico
  void _performMeasurementWithType(String measurementType) {
    if (_glucoseCharacteristic == null) return;

    _currentMeasurementType = measurementType;

    _ble.writeCharacteristicWithResponse(
      _glucoseCharacteristic!,
      value: Uint8List.fromList([0x01]),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Medición ${measurementType == 'ayuno' ? 'en ayuno' : 'posprandial'} en progreso...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateDateTime(){
    final now = DateTime.now().toUtc().add(const Duration(hours: -6));
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    
    final dayIndex = now.weekday - 1;
    final day = dayNames[dayIndex];
    
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'pm' : 'am';
    final minute = now.minute.toString().padLeft(2, '0');
    
    setState(() {
      _dateTime = "$day ${now.day} ${monthNames[now.month - 1]} a las $hour:$minute $amPm";
    });
  }

  // Mostrar diálogo para seleccionar tipo de medición
  Future<String?> _showMeasurementTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tipo de medición',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Cuándo realizas esta medición?',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop('ayuno'),
                    icon: const Icon(Icons.breakfast_dining, color: Colors.white),
                    label: const Text(
                      'En ayuno',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1530AE),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop('posprandial'),
                    icon: const Icon(Icons.restaurant, color: Colors.white),
                    label: const Text(
                      'Después de comer',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1530AE),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Cargar datos del usuario desde Firebase
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _database.child('users/${user.uid}').get();
        if (snapshot.exists) {
          setState(() {
            _userData = Map<String, dynamic>.from(snapshot.value as Map);
            _userName = _userData['nombre'] ?? "Usuario";
            _userLastName = _userData['apellido'] ?? "";
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar los datos del usuario: $e');
    }
  }
  
  // Cargar la última medición desde Firebase
  Future<void> _loadLatestMeasurement() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _database
        .child('users/${user.uid}/readings')
        .orderByChild('timestamp')
        .limitToLast(1)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final latest = data.values.first;
      
      setState(() {
        _glucoseValue = (latest['value'] as num).toString();
        _dateTime = _formatDate(latest['timestamp']);
      });
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('EEEE dd MMMM - hh:mm a').format(date); 
  }
  
  // Mostrar el diálogo de conexión Bluetooth
  void _showBluetoothConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Conexión Bluetooth',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isBluetoothConnected)
                            Column(
                              children: [
                                if (!_isScanning)
                                  ElevatedButton(
                                    onPressed: () => _startBleScan(setState),
                                    child: const Text('Buscar dispositivos'),
                                  ),
                                if (_isScanning)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Column(
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 8),
                                        Text('Buscando dispositivos...'),
                                      ],
                                    ),
                                  ),
                                
                                if (_discoveredDevices.isNotEmpty)
                                  Container(
                                    height: 200,
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      itemCount: _discoveredDevices
                                          .where((device) => device.name.isNotEmpty)
                                          .length,
                                      itemBuilder: (context, index) {
                                        final devices = _discoveredDevices
                                            .where((device) => device.name.isNotEmpty)
                                            .toList();
                                        final device = devices[index];
                                        
                                        return ListTile(
                                          title: Text(
                                            device.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            device.id,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () => _connectToDevice(device, setState),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          
                          if (_isBluetoothConnecting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Conectando...'),
                                ],
                              ),
                            ),

                          if (_isBluetoothConnected)
                            Column(
                              children: [
                                const Icon(Icons.bluetooth_connected, 
                                  color: Colors.blue, size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                  'Dispositivo conectado',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Coloca tu dedo cuando el LED esté en verde',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final navigator = Navigator.of(context);
                                      final measurementType = await _showMeasurementTypeDialog();
                                      
                                      if (measurementType != null) {
                                        navigator.pop();
                                        _performMeasurementWithType(measurementType);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1530AE),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Iniciar medición'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _disconnectDevice();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startBleScan(void Function(void Function()) setState) async {
    setState(() => _isScanning = true);
    _discoveredDevices.clear();
    
    await _checkPermissions();
    
    try {
      _scanSubscription?.cancel();
      _scanSubscription = _ble.scanForDevices(withServices: []).listen(
        (device) {
          final bool deviceAlreadyFound = _discoveredDevices.any((d) => d.id == device.id);
          if (!deviceAlreadyFound) {
            setState(() => _discoveredDevices.add(device));
          }
        },
        onError: (e) {
          setState(() => _isScanning = false);
        },
        onDone: () {
          setState(() => _isScanning = false);
        },
      );
      
      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning) {
          _scanSubscription?.cancel();
          setState(() => _isScanning = false);
        }
      });
    } catch (e) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _checkPermissions() async {
    final bleStatus = _ble.status;
    
    if (bleStatus != BleStatus.ready) {
      await Permission.location.request();
      await Permission.bluetooth.request();
      await Permission.bluetoothConnect.request();
      await Permission.bluetoothScan.request();
    }
  }

  void _connectToDevice(DiscoveredDevice device, void Function(void Function()) dialogSetState) async {
    dialogSetState(() => _isBluetoothConnecting = true);
    
    _connection = _ble.connectToDevice(id: device.id).listen(
      (update) async {
        if (update.connectionState == DeviceConnectionState.connected) {
          _glucoseCharacteristic = QualifiedCharacteristic(
            serviceId: Uuid.parse("0000ffe0-0000-1000-8000-00805f9b34fb"),
            characteristicId: Uuid.parse("0000ffe1-0000-1000-8000-00805f9b34fb"),
            deviceId: device.id,
          );
          
          _ble.subscribeToCharacteristic(_glucoseCharacteristic!).listen((data) {
            final reading = String.fromCharCodes(data);
            if (reading.startsWith("GLUCOSE:")) {
              try {
                final value = double.tryParse(reading.split(":")[1].trim()) ?? 0.0;
                
                if (mounted) {
                  setState(() {
                    _glucoseValue = value.toString();
                  });
                  _saveToFirebase(value);
                }
              } catch (e) {
                debugPrint("Error procesando lectura: $e");
              }
            }
          });

          dialogSetState(() {
            _isBluetoothConnecting = false;
            _isBluetoothConnected = true;
          });
          
          setState(() {
            _isBluetoothConnected = true;
          });
        }
      },
      onError: (error) {
        _disconnectDevice();
        dialogSetState(() {
          _isBluetoothConnecting = false;
        });
      },
    );
  }

  void _disconnectDevice() {
    _scanSubscription?.cancel();
    _connection?.cancel();
    setState(() {
      _isBluetoothConnected = false;
      _isScanning = false;
      _discoveredDevices.clear();
    });
  }

  Future<void> _saveToFirebase(double glucoseLevel) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final measurementData = {
      'value': glucoseLevel,
      'timestamp': ServerValue.timestamp,
      'unit': 'mg/dL',
      'device': 'Bluetooth',
      'measurementType': _currentMeasurementType ?? 'no_especificado',
      'status': _getGlucoseStatus(glucoseLevel, _currentMeasurementType ?? 'ayuno'),
    };

    await _database.child('users/${user.uid}/readings').push().set(measurementData);
    
    _currentMeasurementType = null;
    
    setState(() {
      _glucoseValue = glucoseLevel.toString();
      _updateDateTime();
    });
    // El contador se actualiza automáticamente gracias al StreamSubscription
  }

  String _getGlucoseStatus(double glucose, String type) {
    if (type == 'ayuno') {
      if (glucose < 70) return 'Bajo';
      if (glucose <= 100) return 'Normal';
      if (glucose <= 125) return 'Alto';
      return 'Diabetes';
    } else {
      if (glucose < 70) return 'Bajo';
      if (glucose <= 140) return 'Normal';
      if (glucose <= 199) return 'Alto';
      return 'Diabetes';
    }
  }

  void _goToHistory() {
    Navigator.pushNamed(context, '/history');
  }
    
  void _signOut() async {
    final navigator = Navigator.of(context);
    try {
      await _auth.signOut();
      navigator.pushReplacementNamed('/');
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1A1F71)),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserProfile(),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  _dateTime,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Glucosa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F71),
                ),
              ),
              
              const Text(
                'mg/dL',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1F71),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.shade300,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _glucoseValue.toString(),
                      style: const TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // *** AQUÍ ESTÁ EL CAMBIO PRINCIPAL ***
              // Mediciones diarias reactivas
              _buildWeeklyProgress(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // *** NUEVO MÉTODO PARA CONSTRUIR EL PROGRESO SEMANAL ***
  Widget _buildWeeklyProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mediciones diarias',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1F71),
          ),
        ),
        
        const Text(
          'Últimos 7 días',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Indicadores de días
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDayIndicator(0, 'D'),
            _buildDayIndicator(1, 'L'),
            _buildDayIndicator(2, 'M'),
            _buildDayIndicator(3, 'M'),
            _buildDayIndicator(4, 'J'),
            _buildDayIndicator(5, 'V'),
            _buildDayIndicator(6, 'S'),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Contador de días REACTIVO
        Row(
          children: [
            Text(
              '${_getCompletedReadingsCount()}/7',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Spacer(),
          ],
        ),
        
        const Text(
          'Logrado',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {},
                  color: Colors.grey,
                ),
                const Text(
                  'Inicio',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showBluetoothConnectionDialog,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Nueva medición',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ],
            ),
            
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _goToHistory,
                  color: Colors.grey,
                ),
                const Text(
                  'Historial',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // *** MÉTODO MODIFICADO PARA USAR DATOS REACTIVOS ***
  Widget _buildDayIndicator(int index, String day) {
    final bool hasReading = _hasReadingForDay(index);
    
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasReading ? Colors.blue : Colors.white,
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
          child: hasReading
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserProfile() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF660066),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¡Hola!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Text(
              "$_userName $_userLastName",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}