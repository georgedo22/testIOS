import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:habibuv2/Governorate_Projects.dart';
import 'package:habibuv2/InventoryApp/api_service.dart';
import 'package:habibuv2/InventoryApp/spare_part.dart';
import 'package:habibuv2/Machines.dart';
import 'package:habibuv2/Project.dart';
import 'package:habibuv2/ProjectInformationScreen.dart';
import 'package:habibuv2/ReportsPage.dart';
import 'package:habibuv2/StateData.dart';
import 'package:habibuv2/admin/AdminDashboard.dart';
import 'package:habibuv2/control_login/ProjectDetailsPageAreaManager.dart';
import 'package:habibuv2/main.dart';
import 'package:habibuv2/models/vehicle.dart';
import 'package:habibuv2/services/vehicle_service.dart';
import 'package:habibuv2/states_page.dart';
import 'package:habibuv2/users_page.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:habibuv2/widgets/vehicle_dialog.dart';
import 'package:http/http.dart' as http;

class Dashboard extends StatefulWidget {
  late int governorateId;
  @override
  State<Dashboard> createState() => _DashboardState();

  Dashboard({Key? key, required this.governorateId}) : super(key: key);
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  int stockItemsCount = 0;
  int workingMachinesCount = 0;
  int stoppedMachinesCount = 0;
  int underMaintenanceMachinesCount = 0;
  int totalMachinesCount = 0;
  //Timer? _timer;
  List<SparePart> stockItems = [];
  SparePart? selectedItem;
  bool isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<ProjectInvoiceSummary> projectSummaries = [];
  List<Governorate_Projects> governorateProjects = [];
  Future<void> fetchProjectSummaries() async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/admin/project_invoice_summary.php'),
        body: {
          'governorate_id': widget.governorateId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() {
            projectSummaries = (jsonData['data'] as List)
                .map((item) => ProjectInvoiceSummary.fromJson(item))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching project summaries: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _loadInitialData();
    //_timer =Timer.periodic(Duration(seconds: 60), (Timer t) => _loadInitialData());
  }

  @override
  void dispose() {
    //_timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        fetchStockItems(),
        fetchMachinesCount(),
        fetchProjectSummaries(),
        fetchStatesWithProjects(),
      ]);
      _fadeController.forward();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStockItems() async {
    try {
      final items =
          await ApiService.getAllPartsbygovernorates(widget.governorateId);
      setState(() {
        stockItems = items;
        stockItemsCount = items.length;
        if (stockItems.isNotEmpty) {
          selectedItem = stockItems[0];
        }
      });
    } catch (e) {
      print('Error fetching stock items: $e');
      setState(() {
        stockItems = [];
        stockItemsCount = 0;
      });
    }
  }

  Future<void> fetchMachinesCount() async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/admin/fetch_machine.php'),
        body: {
          'governorate_id': widget.governorateId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        int workingCount = 0;
        int stoppedCount = 0;
        int maintenanceCount = 0;

        for (var item in jsonData) {
          final status = item['status'];
          if (status != null) {
            if (status == 'active') {
              workingCount++;
            } else if (status == 'stop') {
              stoppedCount++;
            } else if (status == 'maintenance') {
              maintenanceCount++;
            }
          }
        }

        setState(() {
          workingMachinesCount = workingCount;
          stoppedMachinesCount = stoppedCount;
          underMaintenanceMachinesCount = maintenanceCount;
          totalMachinesCount = jsonData.length;
        });
      }
    } catch (e) {
      print('Error fetching machine data: $e');
      setState(() {
        workingMachinesCount = 0;
        stoppedMachinesCount = 0;
        underMaintenanceMachinesCount = 0;
        totalMachinesCount = 0;
      });
    }
  }

  void _showStockDetails(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: stockItems.length,
                  itemBuilder: (context, index) {
                    final item = stockItems[index];
                    final isLowStock = item.quantity <= item.minimumThreshold;
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        title: Text(item.partName),
                        subtitle: Text('Part Code: ${item.partCode}'),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quantity: ${item.quantity}'),
                                Text(
                                  'Min. Threshold: ${item.minimumThreshold}',
                                  style: TextStyle(
                                    color:
                                        isLowStock ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                    'Price: \$${item.price.toStringAsFixed(2)}'),
                                Text(
                                    'Storage Location: ${item.storageLocation}'),
                              ],
                            ),
                          ),
                        ],
                        trailing: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isLowStock ? 'Low Stock' : 'In Stock',
                            style: TextStyle(
                              color: isLowStock ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  void _showMachinesDetails(BuildContext context, String title) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/fetch_machin.php'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        // Adapt to new data structure
        List<Vehicle> machines =
            jsonData.map((item) => Vehicle.fromJson(item)).toList();

        // Filter by status according to new API
        if (title == "Active Machines") {
          machines =
              machines.where((machine) => machine.status == "active").toList();
        } else if (title == "Under Maintenance") {
          machines = machines
              .where((machine) => machine.status == "maintenance")
              .toList();
        } else if (title == "Idle Machines") {
          machines =
              machines.where((machine) => machine.status == "stop").toList();
        }

        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: 600, maxHeight: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: machines.length,
                      itemBuilder: (context, index) {
                        final item = machines[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('${item.vehicleType} - ${item.model}'),
                            subtitle: Text(
                                'Vehicle Number : ${item.vehicleNumber}\n Location ${item.currentLocation}'),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: item.status == 'active'
                                    ? Colors.green.withOpacity(0.1)
                                    : item.status == 'stop'
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(item.status),
                                style: TextStyle(
                                  color: item.status == 'active'
                                      ? Colors.green
                                      : item.status == 'stop'
                                          ? Colors.red
                                          : Colors.orange,
                                  fontWeight: FontWeight.bold,
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
            ),
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to load machines: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'active';
      case 'stop':
        return 'stop';
      case 'maintenance':
        return 'maintenance';
      default:
        return status;
    }
  }

  Future<void> fetchStatesWithProjects() async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://antiquewhite-cobra-422929.hostingersite.com/georgecode/admin/fetch_projects_by_gov.php'),
        body: {'governorate_id': widget.governorateId.toString()},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("Response data: $jsonData");
        List<dynamic> projectsList;
        if (jsonData is List) {
          projectsList = jsonData;
        } else if (jsonData is Map && jsonData['data'] is List) {
          projectsList = jsonData['data'];
        } else {
          projectsList = [];
        }

        governorateProjects = projectsList
            .map((item) => Governorate_Projects.fromJson(item))
            .toList();
        print("Projects by governorate: $governorateProjects");
      }
    } catch (e) {
      print('Error fetching project summaries: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
          ),
        ],
      ),
      /*drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.shade800],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/person.jpg'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.blue),
              title: Text('States'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.people, color: Colors.blue),
              title: Text('Users'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UsersPage()),
                );
              },
            },
            ListTile(
              leading: Icon(Icons.bar_chart, color: Colors.blue),
              title: Text('Reports'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportsPage()),
                );
              },
            ),
          ],
        ),
      ),*/
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      SizedBox(height: 24),
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                          final bool isNarrowScreen =
                              constraints.maxWidth < 600;
                          final List<Widget> statCards = [
                            InkWell(
                              onTap: () =>
                                  _showStockDetails(context, 'Stock Items'),
                              child: _buildStatCard(
                                'Stock Items',
                                stockItemsCount.toString(),
                                Icons.inventory,
                                Colors.blue,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showMachinesDetails(
                                  context, 'Active Machines'),
                              child: _buildStatCard(
                                'Active Machines',
                                workingMachinesCount.toString(),
                                Icons.settings,
                                Colors.green,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showMachinesDetails(
                                  context, 'Under Maintenance'),
                              child: _buildStatCard(
                                'Under Maintenance',
                                underMaintenanceMachinesCount.toString(),
                                Icons.build,
                                Colors.orange,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showMachinesDetails(
                                  context, 'Idle Machines'),
                              child: _buildStatCard(
                                'Idle Machines',
                                stoppedMachinesCount.toString(),
                                Icons.pause_circle_outline,
                                Colors.red,
                              ),
                            ),
                          ];

                          return isNarrowScreen
                              ? GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 16.0,
                                  crossAxisSpacing: 16.0,
                                  childAspectRatio: 1.2,
                                  children: statCards,
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: statCards,
                                );
                        },
                      ),
                      SizedBox(height: 32),
                      Card(
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Machine Status',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              SizedBox(height: 20),
                              SizedBox(
                                height: 250,
                                child: _buildPieChart(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      Card(
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Overview',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              SizedBox(height: 20),
                              SizedBox(
                                height: 300,
                                child: _buildBarChart(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      Card(
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'project_invoice_summary',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              SizedBox(height: 20),
                              SizedBox(
                                height: 300,
                                child: _buildProjectBudgetChart(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      Card(
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Projects',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              SizedBox(height: 20),
                              FutureBuilder<void>(
                                future: fetchStatesWithProjects(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Center(
                                        child:
                                            Text("Error: ${snapshot.error}"));
                                  } else {
                                    if (governorateProjects.isEmpty) {
                                      return Center(
                                          child: Text("No data available"));
                                    }
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: governorateProjects.length,
                                      itemBuilder: (context, index) {
                                        final state =
                                            governorateProjects[index];
                                        return Card(
                                          margin:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: ListTile(
                                            title: Text(
                                              state.project_name.toString(),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(
                                              'Supervisor Name: ${state.supervisor_name}'
                                                  .toString(),
                                            ),
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  Colors.blue.shade50,
                                              child: Icon(
                                                Icons.location_city,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            trailing: Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.blue,
                                              size: 16,
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        ProjectDetailsPageAreaManager(
                                                            project: {
                                                              'project_id': state
                                                                  .project_id,

                                                              // add other fields as needed
                                                            })),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 180,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final data = [
      _ChartData('Active', workingMachinesCount, Colors.green),
      _ChartData('Maintenance', underMaintenanceMachinesCount, Colors.orange),
      _ChartData('Idle', stoppedMachinesCount, Colors.red),
    ];

    final series = [
      charts.Series<_ChartData, String>(
        id: 'Machine Status',
        domainFn: (data, _) => data.label,
        measureFn: (data, _) => data.value,
        colorFn: (data, _) => charts.ColorUtil.fromDartColor(data.color),
        labelAccessorFn: (data, _) => '${data.label}\n${data.value}',
        data: data,
      ),
    ];

    return charts.PieChart<String>(
      series,
      animate: true,
      defaultRenderer: charts.ArcRendererConfig(
        arcWidth: 60,
        strokeWidthPx: 0,
        arcRendererDecorators: [
          charts.ArcLabelDecorator(
            labelPosition: charts.ArcLabelPosition.outside,
            insideLabelStyleSpec: charts.TextStyleSpec(
              fontSize: 12,
              color: charts.MaterialPalette.white,
            ),
            outsideLabelStyleSpec: charts.TextStyleSpec(
              fontSize: 12,
              color: charts.MaterialPalette.gray.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    // Sort items by quantity and take top 10 for better visualization
    final sortedItems = List<SparePart>.from(stockItems)
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    final topItems = sortedItems.take(10).toList();

    final data = topItems.map((item) {
      String displayName = item.partName;
      // Add part code for unique identification
      displayName = displayName.length > 15
          ? '${displayName.substring(0, 12)}... (${item.partCode})'
          : '$displayName (${item.partCode})';

      return _ChartData(displayName, item.quantity,
          item.quantity <= item.minimumThreshold ? Colors.red : Colors.blue);
    }).toList();

    final series = [
      charts.Series<_ChartData, String>(
        id: 'Inventory',
        domainFn: (_ChartData data, _) => data.label,
        measureFn: (_ChartData data, _) => data.value,
        colorFn: (_ChartData data, _) =>
            charts.ColorUtil.fromDartColor(data.color),
        data: data,
        labelAccessorFn: (_ChartData data, _) => '${data.value}',
      ),
    ];

    return charts.BarChart(
      series,
      animate: true,
      vertical: false,
      barRendererDecorator: charts.BarLabelDecorator<String>(),
      domainAxis: charts.OrdinalAxisSpec(
        renderSpec: charts.SmallTickRendererSpec(
          labelRotation: 0,
          labelStyle: charts.TextStyleSpec(
            fontSize: 10,
            color: charts.MaterialPalette.gray.shade600,
          ),
        ),
      ),
      primaryMeasureAxis: charts.NumericAxisSpec(
        tickProviderSpec: charts.BasicNumericTickProviderSpec(
          desiredTickCount: 6,
        ),
      ),
    );
  }

  Widget _buildProjectBudgetChart() {
    if (projectSummaries.isEmpty) {
      return Center(child: Text('No project data available'));
    }

    final budgetData = projectSummaries
        .map((project) => _ChartData(
            project.projectName, project.budget.toInt(), Colors.blue.shade400))
        .toList();

    final invoiceData = projectSummaries
        .map((project) => _ChartData(project.projectName,
            project.invoicesTotal.toInt(), Colors.green.shade400))
        .toList();

    final series = [
      charts.Series<_ChartData, String>(
        id: 'Budget',
        domainFn: (_ChartData data, _) => data.label,
        measureFn: (_ChartData data, _) => data.value,
        colorFn: (_ChartData data, _) =>
            charts.ColorUtil.fromDartColor(data.color),
        data: budgetData,
        labelAccessorFn: (_ChartData data, _) =>
            '\$${(data.value).toStringAsFixed(1)}',
      ),
      charts.Series<_ChartData, String>(
        id: 'Invoices',
        domainFn: (_ChartData data, _) => data.label,
        measureFn: (_ChartData data, _) => data.value,
        colorFn: (_ChartData data, _) =>
            charts.ColorUtil.fromDartColor(data.color),
        data: invoiceData,
        labelAccessorFn: (_ChartData data, _) =>
            '\$${(data.value).toStringAsFixed(1)}',
      ),
    ];

    return SizedBox(
      height: 300,
      child: charts.BarChart(
        series,
        animate: true,
        barGroupingType: charts.BarGroupingType.grouped,
        vertical: false,
        barRendererDecorator: charts.BarLabelDecorator<String>(),
        domainAxis: charts.OrdinalAxisSpec(
          renderSpec: charts.SmallTickRendererSpec(
            labelRotation: 0,
            labelStyle: charts.TextStyleSpec(
              fontSize: 10,
              color: charts.MaterialPalette.gray.shade600,
            ),
          ),
        ),
        behaviors: [
          charts.SeriesLegend(
            position: charts.BehaviorPosition.top,
            horizontalFirst: false,
            desiredMaxRows: 2,
            cellPadding: EdgeInsets.only(right: 16.0, bottom: 4.0),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String label;
  final int value;
  final Color color;

  _ChartData(this.label, this.value, this.color);
}

class ProjectInvoiceSummary {
  final int id;
  final String projectName;
  final double budget;
  final double invoicesTotal;

  ProjectInvoiceSummary({
    required this.id,
    required this.projectName,
    required this.budget,
    required this.invoicesTotal,
  });

  double get completionPercentage => (invoicesTotal / budget) * 100;

  factory ProjectInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return ProjectInvoiceSummary(
      id: json['id'] ?? 0,
      projectName: json['projectName'] ?? json['project_name'] ?? '',
      budget: json['budget'] != null
          ? double.tryParse(json['budget'].toString()) ?? 0
          : 0,
      invoicesTotal: json['invoicesTotal'] != null
          ? double.tryParse(json['invoicesTotal'].toString()) ?? 0
          : (json['total_invoices'] != null
              ? double.tryParse(json['total_invoices'].toString()) ?? 0
              : 0),
    );
  }
}
