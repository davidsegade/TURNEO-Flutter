import 'package:flutter/material.dart';
import 'data/turneo_repository.dart';
import 'models/turneo_models.dart';

class TurneoApp extends StatelessWidget {
  const TurneoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TURNEO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF080D14),
        cardColor: const Color(0xFF101823),
      ),
      home: const GeneralScreen(),
    );
  }
}

class GeneralScreen extends StatefulWidget {
  const GeneralScreen({super.key});
  @override State<GeneralScreen> createState()=>_GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  final repo=TurneoRepository();
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  late Future<MonthData> data;
  @override void initState(){super.initState();data=repo.loadMonth(month);}
  void move(int n){setState((){month=DateTime(month.year,month.month+n);data=repo.loadMonth(month);});}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar: AppBar(title:const Text('TURNEO'),centerTitle:true),
    body:FutureBuilder<MonthData>(
      future:data,
      builder:(context,s){
        if(s.hasError)return Center(child:Text('Error: ${s.error}'));
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        final d=s.data!;
        return Column(children:[
          Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
            IconButton(onPressed:()=>move(-1),icon:const Icon(Icons.chevron_left)),
            Expanded(child:Center(child:Text(d.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700)))),
            IconButton(onPressed:()=>move(1),icon:const Icon(Icons.chevron_right)),
          ])),
          Expanded(child:MonthGrid(data:d)),
        ]);
      },
    ),
  );
}

class MonthGrid extends StatelessWidget{
  final MonthData data; const MonthGrid({super.key,required this.data});
  static const initials={'u2':'C','u1':'D','u3':'A','u4':'J'};
  @override Widget build(BuildContext context){
    final first=DateTime(data.month.year,data.month.month,1);
    final offset=first.weekday-1;
    final days=DateTime(data.month.year,data.month.month+1,0).day;
    return GridView.builder(
      padding:const EdgeInsets.all(6),
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:.58,crossAxisSpacing:3,mainAxisSpacing:3),
      itemCount:offset+days,
      itemBuilder:(context,i){
        if(i<offset)return const SizedBox.shrink();
        final day=i-offset+1,date=DateTime(data.month.year,data.month.month,day);
        final key='${date.year}-${date.month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
        return Container(
          padding:const EdgeInsets.all(3),
          decoration:BoxDecoration(color:const Color(0xFF101823),borderRadius:BorderRadius.circular(8)),
          child:Column(children:[
            Text('$day',style:const TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:2),
            for(final uid in const ['u2','u1','u3','u4'])
              Expanded(child:Container(
                width:double.infinity,margin:const EdgeInsets.symmetric(vertical:1),padding:const EdgeInsets.symmetric(horizontal:2),
                decoration:BoxDecoration(color:data.serviceColor(data.assignments['$uid|$key']),borderRadius:BorderRadius.circular(4)),
                child:FittedBox(fit:BoxFit.scaleDown,child:Text('${initials[uid]} ${data.assignments['$uid|$key']??'—'}',style:const TextStyle(fontWeight:FontWeight.w700))),
              )),
          ]),
        );
      },
    );
  }
}
