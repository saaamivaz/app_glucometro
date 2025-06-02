import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
 const HistoryScreen({super.key});

 @override
 State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
 final FirebaseAuth _auth = FirebaseAuth.instance;
 final DatabaseReference _database = FirebaseDatabase.instance.ref();
 
 // Variables para filtros
 String _selectedPeriod = 'Últimos 7 días';
 String _selectedType = 'Todos';
 String _selectedStatus = 'Todos';
 
 final List<String> _periodOptions = [
   'Últimos 7 días',
   'Últimos 30 días', 
   'Últimos 3 meses',
   'Último año',
   'Todo el historial'
 ];
 
 final List<String> _typeOptions = [
   'Todos',
   'En ayuno',
   'Posprandial'
 ];
 
 final List<String> _statusOptions = [
   'Todos',
   'Normal',
   'Alto',
   'Bajo',
 ];

 @override
 Widget build(BuildContext context) {
   final user = _auth.currentUser;
   
   if (user == null) {
     return const Scaffold(
       body: Center(
         child: Text('Usuario no autenticado'),
       ),
     );
   }

   return Scaffold(
     appBar: AppBar(
       title: const Text(
         'Historial de mediciones',
         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
       ),
       backgroundColor: Colors.white,
       foregroundColor: const Color(0xFF1A1F71),
       elevation: 0,
       leading: IconButton(
         icon: const Icon(Icons.arrow_back),
         onPressed: () => Navigator.pop(context),
       ),
     ),
     body: StreamBuilder<DatabaseEvent>(
       stream: _database
           .child('users/${user.uid}/readings')
           .orderByChild('timestamp')
           .onValue,
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
         }
         
         if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
           return _buildEmptyState();
         }

         final data = Map<String, dynamic>.from(
           snapshot.data!.snapshot.value as Map
         );
         
         List<Map<String, dynamic>> readings = data.entries.map((entry) {
           final reading = Map<String, dynamic>.from(entry.value as Map);
           return {
             'id': entry.key,
             'value': reading['value']?.toDouble() ?? 0.0,
             'timestamp': reading['timestamp'] ?? 0,
             'measurementType': reading['measurementType'] ?? 'no_especificado',
             'status': reading['status'] ?? 'Normal',
           };
         }).toList();
         
         // Aplicar filtros
         readings = _applyFilters(readings);
         
         // Ordenar por timestamp descendente
         readings.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
         
         return Column(
           children: [
             // Filtros
             _buildFilters(),
             
             // Estadísticas rápidas
             if (readings.isNotEmpty) _buildQuickStats(readings),
             
             // Lista de mediciones
             Expanded(
               child: readings.isEmpty 
                 ? _buildNoResultsState()
                 : ListView.builder(
                     itemCount: readings.length,
                     itemBuilder: (context, index) {
                       final reading = readings[index];
                       return _buildMeasurementCard(reading);
                     },
                   ),
             ),
           ],
         );
       },
     ),
   );
 }

 // Aplicar filtros a las lecturas
 List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> readings) {
   List<Map<String, dynamic>> filtered = List.from(readings);
   
   // Filtro por período
   if (_selectedPeriod != 'Todo el historial') {
     final now = DateTime.now();
     late DateTime startDate;
     
     switch (_selectedPeriod) {
       case 'Últimos 7 días':
         startDate = now.subtract(const Duration(days: 7));
         break;
       case 'Últimos 30 días':
         startDate = now.subtract(const Duration(days: 30));
         break;
       case 'Últimos 3 meses':
         startDate = now.subtract(const Duration(days: 90));
         break;
       case 'Último año':
         startDate = now.subtract(const Duration(days: 365));
         break;
     }
     
     filtered = filtered.where((reading) {
       final readingDate = DateTime.fromMillisecondsSinceEpoch(reading['timestamp']);
       return readingDate.isAfter(startDate);
     }).toList();
   }
   
   // Filtro por tipo de medición
   if (_selectedType != 'Todos') {
     String typeFilter = _selectedType == 'En ayuno' ? 'ayuno' : 'posprandial';
     filtered = filtered.where((reading) => 
       reading['measurementType'] == typeFilter).toList();
   }
   
   // Filtro por estado
   if (_selectedStatus != 'Todos') {
     filtered = filtered.where((reading) => 
       reading['status'] == _selectedStatus).toList();
   }
   
   return filtered;
 }

 Widget _buildFilters() {
   return Padding(
     padding: const EdgeInsets.all(16.0),
     child: Row(
       children: [
         // Filtro de período
         Expanded(
           child: GestureDetector(
             onTap: _showPeriodFilter,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.grey.shade300),
                 borderRadius: BorderRadius.circular(8),
                 color: Colors.white,
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Flexible(
                     child: Text(
                       _selectedPeriod,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(fontSize: 14),
                     ),
                   ),
                   const Icon(Icons.arrow_drop_down, size: 20),
                 ],
               ),
             ),
           ),
         ),
         const SizedBox(width: 16),
         
         // Filtro avanzado
         GestureDetector(
           onTap: _showAdvancedFilters,
           child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               border: Border.all(color: Colors.grey.shade300),
               borderRadius: BorderRadius.circular(8),
               color: (_selectedType != 'Todos' || _selectedStatus != 'Todos') 
                 ? const Color(0xFF1530AE).withValues(alpha: 0.1)
                 : Colors.white,
             ),
             child: Icon(
               Icons.tune,
               color: (_selectedType != 'Todos' || _selectedStatus != 'Todos')
                 ? const Color(0xFF1530AE)
                 : Colors.grey[600],
               size: 20,
             ),
           ),
         ),
       ],
     ),
   );
 }

 // Mostrar filtro de período
 void _showPeriodFilter() {
   showModalBottomSheet(
     context: context,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
     ),
     builder: (context) {
       return Container(
         padding: const EdgeInsets.all(16),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text(
               'Seleccionar período',
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
               ),
             ),
             const SizedBox(height: 16),
             ...(_periodOptions.map((period) => ListTile(
               title: Text(period),
               trailing: _selectedPeriod == period 
                 ? const Icon(Icons.check, color: Color(0xFF1530AE))
                 : null,
               onTap: () {
                 setState(() {
                   _selectedPeriod = period;
                 });
                 Navigator.pop(context);
               },
             ))),
           ],
         ),
       );
     },
   );
 }

 // Mostrar filtros avanzados
 void _showAdvancedFilters() {
   showModalBottomSheet(
     context: context,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
     ),
     isScrollControlled: true,
     builder: (context) {
       return StatefulBuilder(
         builder: (context, setModalState) {
           return Container(
             padding: const EdgeInsets.all(16),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text(
                       'Filtros avanzados',
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     TextButton(
                       onPressed: () {
                         setModalState(() {
                           _selectedType = 'Todos';
                           _selectedStatus = 'Todos';
                         });
                       },
                       child: const Text('Limpiar'),
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 
                 // Filtro por tipo
                 const Text(
                   'Tipo de medición',
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
                 const SizedBox(height: 8),
                 Wrap(
                   spacing: 8,
                   children: _typeOptions.map((type) => FilterChip(
                     label: Text(type),
                     selected: _selectedType == type,
                     onSelected: (selected) {
                       setModalState(() {
                         _selectedType = type;
                       });
                     },
                     selectedColor: const Color(0xFF1530AE).withValues(alpha:0.2),
                     checkmarkColor: const Color(0xFF1530AE),
                   )).toList(),
                 ),
                 
                 const SizedBox(height: 16),
                 
                 // Filtro por estado
                 const Text(
                   'Estado de glucosa',
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
                 const SizedBox(height: 8),
                 Wrap(
                   spacing: 8,
                   children: _statusOptions.map((status) => FilterChip(
                     label: Text(status),
                     selected: _selectedStatus == status,
                     onSelected: (selected) {
                       setModalState(() {
                         _selectedStatus = status;
                       });
                     },
                     selectedColor: const Color(0xFF1530AE).withValues(alpha: 0.2),
                     checkmarkColor: const Color(0xFF1530AE),
                   )).toList(),
                 ),
                 
                 const SizedBox(height: 24),
                 
                 // Botón aplicar
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: () {
                       setState(() {
                         // Los filtros ya están aplicados en las variables
                       });
                       Navigator.pop(context);
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF1530AE),
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(8),
                       ),
                     ),
                     child: const Text('Aplicar filtros'),
                   ),
                 ),
               ],
             ),
           );
         },
       );
     },
   );
 }

 // Widget para estadísticas rápidas
 Widget _buildQuickStats(List<Map<String, dynamic>> readings) {
   double average = readings.map((r) => r['value'] as double).reduce((a, b) => a + b) / readings.length;
   double highest = readings.map((r) => r['value'] as double).reduce((a, b) => a > b ? a : b);
   double lowest = readings.map((r) => r['value'] as double).reduce((a, b) => a < b ? a : b);
   
   return Container(
     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: const Color(0xFF1530AE).withValues(alpha:0.05),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: const Color(0xFF1530AE).withValues(alpha: 0.1)),
     ),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceAround,
       children: [
         _buildStatItem('Promedio', '${average.toInt()}', 'mg/dL'),
         _buildStatItem('Máximo', '${highest.toInt()}', 'mg/dL'),
         _buildStatItem('Mínimo', '${lowest.toInt()}', 'mg/dL'),
         _buildStatItem('Total', '${readings.length}', 'mediciones'),
       ],
     ),
   );
 }

 Widget _buildStatItem(String label, String value, String unit) {
   return Column(
     children: [
       Text(
         value,
         style: const TextStyle(
           fontSize: 18,
           fontWeight: FontWeight.bold,
           color: Color(0xFF1530AE),
         ),
       ),
       Text(
         unit,
         style: TextStyle(
           fontSize: 10,
           color: Colors.grey[600],
         ),
       ),
       Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[700],
         ),
       ),
     ],
   );
 }

 Widget _buildEmptyState() {
   return const Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(Icons.history, size: 64, color: Colors.grey),
         SizedBox(height: 16),
         Text(
           'No hay mediciones registradas',
           style: TextStyle(fontSize: 18, color: Colors.grey),
         ),
         SizedBox(height: 8),
         Text(
           'Realiza tu primera medición para ver el historial',
           style: TextStyle(fontSize: 14, color: Colors.grey),
         ),
       ],
     ),
   );
 }

 Widget _buildNoResultsState() {
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
         const SizedBox(height: 16),
         Text(
           'No se encontraron mediciones',
           style: TextStyle(fontSize: 18, color: Colors.grey[600]),
         ),
         const SizedBox(height: 8),
         Text(
           'Intenta cambiar los filtros de búsqueda',
           style: TextStyle(fontSize: 14, color: Colors.grey[500]),
         ),
         const SizedBox(height: 16),
         ElevatedButton(
           onPressed: () {
             setState(() {
               _selectedPeriod = 'Todo el historial';
               _selectedType = 'Todos';
               _selectedStatus = 'Todos';
             });
           },
           child: const Text('Limpiar filtros'),
         ),
       ],
     ),
   );
 }

 Widget _buildMeasurementCard(Map<String, dynamic> reading) {
   final value = reading['value'].toDouble();
   final timestamp = reading['timestamp'];
   final measurementType = reading['measurementType'];
   final status = reading['status'];
   
   // Formatear fecha
   final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
   final dateFormat = DateFormat('EEEE dd MMMM');
   final timeFormat = DateFormat('HH:mm');
   
   // Color según el estado - SIMPLIFICADO
   Color statusColor = Colors.green;
   String statusText = 'Normal';
   
   if (status == 'Prediabetes' || status == 'Diabetes' || status == 'Alto') {
     statusColor = Colors.orange;
     statusText = 'Alto';
   } else if (status == 'Hipoglucemia' || status == 'Bajo') {
     statusColor = Colors.red;
     statusText = 'Bajo';
   } else {
     statusColor = Colors.green;
     statusText = 'Normal';
   }
   
   // Icono según el tipo de medición
   IconData typeIcon = measurementType == 'ayuno' 
       ? Icons.breakfast_dining 
       : measurementType == 'posprandial'
           ? Icons.restaurant
           : Icons.help_outline;
   
   String typeText = measurementType == 'ayuno' 
       ? 'En ayuno' 
       : measurementType == 'posprandial' 
           ? 'Después de comer' 
           : 'No especificado';

   return Card(
     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
     elevation: 2,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(12),
     ),
     child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
         children: [
           // Fila superior: Fecha, valor y estado
           Row(
             children: [
               // Fecha y hora
               Expanded(
                 flex: 3,
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       dateFormat.format(date),
                       style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                       ),
                     ),
                     Text(
                       timeFormat.format(date),
                       style: TextStyle(
                         color: Colors.grey[600],
                         fontSize: 14,
                       ),
                     ),
                   ],
                 ),
               ),
               
               // Valor de glucosa
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1530AE).withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   '${value.toInt()} mg/dL',
                   style: const TextStyle(
                     fontWeight: FontWeight.bold,
                     fontSize: 18,
                     color: Color(0xFF1530AE),
                   ),
                 ),
               ),
               
               const SizedBox(width: 12),
               
               // Estado
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: statusColor.withValues(alpha: 0.2),
                   borderRadius: BorderRadius.circular(6),
                 ),
                 child: Text(
                   statusText,
                   style: TextStyle(
                     color: statusColor,
                     fontWeight: FontWeight.bold,
                     fontSize: 12,
                   ),
                 ),
               ),
             ],
           ),
           
           const SizedBox(height: 12),
           
           // Fila inferior: Tipo de medición (con más espacio)
           Row(
             children: [
               Icon(
                 typeIcon, 
                 size: 18, 
                 color: Colors.grey[600]
               ),
               const SizedBox(width: 8),
               Text(
                 typeText,
                 style: TextStyle(
                   color: Colors.grey[600],
                   fontSize: 14,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }
}