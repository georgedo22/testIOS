import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MachineDetailPage extends StatefulWidget {
  final Map<String, dynamic> machine;

  MachineDetailPage({required this.machine});

  @override
  _MachineDetailPageState createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _maintenanceFuture;

  late Future<List<FuelLog>> _fuelLogsFuture;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _maintenanceFuture =
        fetchMaintenanceSchedule(widget.machine['vehicle_id'].toString());

    _fuelLogsFuture = fetchFuelLogs(widget.machine['vehicle_id']);
  }

  Future<List<Map<String, dynamic>>> fetchMaintenanceSchedule(
      String vehicleId) async {
    final url = Uri.parse(
        'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/get_maintenance_schedule.php');
    final response = await http.post(url, body: {'vehicle_id': vehicleId});

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['success'] == true) {
        return List<Map<String, dynamic>>.from(jsonData['data']);
      } else {
        throw Exception('Server error: ${jsonData['message']}');
      }
    } else {
      throw Exception('Failed to load maintenance schedule');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildMaintenanceTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _maintenanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));

        final data = snapshot.data!;
        if (data.isEmpty)
          return Center(child: Text('No maintenance records found.'));

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('${item['maintenance_type']} - ${item['m_date']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Description: ${item['maintenance_description'] ?? '---'}'),
                    Text('Parts: ${item['parts_replacement'] ?? '---'}'),
                    Text(
                        'Before: ${item['status_before_maintenance'] ?? '---'}'),
                    Text('After: ${item['status_after_maintenance'] ?? '---'}'),
                    Text(
                        'Engine Oil: ${item['oil_eng_quantity']} | Azola: ${item['azola_oil_quantity']}'),
                    if (item['note'] != null &&
                        item['note'].toString().trim().isNotEmpty)
                      Text('Note: ${item['note']}',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkFuelTab() {
    return FutureBuilder<List<FuelLog>>(
      future: _fuelLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No fuel logs available."));
        }

        final logs = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: isWideScreen ? constraints.maxWidth : 600),
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Hour')),
                    DataColumn(label: Text('Last Hour')),
                    DataColumn(label: Text('Worked Hours')),
                    DataColumn(label: Text('Liters')),
                    DataColumn(label: Text('Consumption')),
                    DataColumn(label: Text('Created At')),
                  ],
                  rows: logs.map((log) {
                    return DataRow(cells: [
                      DataCell(Text(log.date)),
                      DataCell(Text(log.hour.toString())),
                      DataCell(Text(log.lasthour.toString())),
                      DataCell(Text(log.hourwork.toString())),
                      DataCell(Text(log.liter.toString())),
                      DataCell(Text(log.consumption.toString())),
                      DataCell(Text(log.created_at)),
                    ]);
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.machine['vehicle_number'] ?? 'Machine Details'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Maintenance schedule'),
            Tab(text: 'Working hours / diesel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMaintenanceTab(),
          _buildWorkFuelTab(), // ستُكمل لاحقًا
        ],
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> fetchMaintenanceSchedule(
    String vehicleId) async {
  final url = Uri.parse(
      'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/get_maintenance_schedule.php');

  final response = await http.post(
    url,
    body: {'vehicle_id': vehicleId},
  );

  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    if (jsonData['success'] == true) {
      List<dynamic> rawData = jsonData['data'];
      return rawData.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Server error: ${jsonData['message']}');
    }
  } else {
    throw Exception('Failed to load maintenance schedule');
  }
}

class FuelLog {
  final String date;
  final int hour;
  final int lasthour;
  final int hourwork;
  final double liter;
  final double consumption;
  final String created_at;

  FuelLog({
    required this.date,
    required this.hour,
    required this.lasthour,
    required this.hourwork,
    required this.liter,
    required this.consumption,
    required this.created_at,
  });

  factory FuelLog.fromJson(Map<String, dynamic> json) {
    return FuelLog(
      date: json['date'],
      hour: int.parse(json['hour'].toString()),
      lasthour: int.parse(json['lasthour'].toString()),
      hourwork: int.parse(json['hourwork'].toString()),
      liter: double.parse(json['liter'].toString()),
      consumption: double.parse(json['consumption'].toString()),
      created_at: json['created_at'] ?? '',
    );
  }
}

Future<List<FuelLog>> fetchFuelLogs(int vehicleId) async {
  final url = Uri.parse(
      "https://antiquewhite-cobra-422929.hostingersite.com/georgecode/get_fuel_work_logs.php?vehicle_id=$vehicleId");

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final body = json.decode(response.body);
    if (body['status']) {
      return (body['data'] as List)
          .map((item) => FuelLog.fromJson(item))
          .toList();
    } else {
      throw Exception(body['message']);
    }
  } else {
    throw Exception("Failed to load fuel logs");
  }
}
