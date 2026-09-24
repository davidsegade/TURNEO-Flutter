import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_screen.dart';
import 'data/turneo_repository.dart';
import 'models/turneo_models.dart';

class TurneoApp extends StatefulWidget{const TurneoApp({super.key});@override State<TurneoApp> createState()=>_TurneoAppState();}
class _TurneoAppState extends State<TurneoApp>{
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'TURNEO',debugShowCheckedModeBanner:false,
    theme:ThemeData.dark(useMaterial3:true).copyWith(scaffoldBackgroundColor:const Color(0xFF080D14),cardColor:const Color(0xFF101823)),
    home:Supabase.instance.client.auth.currentSession==null?LoginScreen(onSignedIn:()=>setState((){})):const GeneralScreen(),
  );
}

class GeneralScreen extends StatefulWidget{const GeneralScreen({super.key});@override State<GeneralScreen> createState()=>_GeneralScreenState();}
class _GeneralScreenState extends State<GeneralScreen>{
  final repo=TurneoRepository();DateTime month=DateTime(DateTime.now().year,DateTime.now().month);late Future<MonthData> data;
  @override void initState(){super.initState();data=repo.loadMonth(month);}
  void move(int n){setState((){month=DateTime(month.year,month.month+n);data=repo.loadMonth(month);});}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('TURNEO',style:TextStyle(fontWeight:FontWeight.w800)),centerTitle:true,actions:[IconButton(onPressed:()async{await Supabase.instance.client.auth.signOut();if(mounted)setState((){});},icon:const Icon(Icons.logout))]),
    body:FutureBuilder<MonthData>(future:data,builder:(context,s){
      if(s.hasError)return Center(child:Text('Error: ${s.error}'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final d=s.data!;return Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[IconButton(onPressed:()=>move(-1),icon:const Icon(Icons.chevron_left)),Expanded(child:Center(child:Text(d.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))),IconButton(onPressed:()=>move(1),icon:const Icon(Icons.chevron_right))])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),child:Row(children:const ['L','M','X','J','V','S','D'].map((x)=>Expanded(child:Center(child:Text(x,style:TextStyle(fontWeight:FontWeight.w700))))).toList())),
        Expanded(child:MonthGrid(data:d)),
      ]);
    }),
  );
}

class MonthGrid extends StatelessWidget{
  final MonthData data;const MonthGrid({super.key,required this.data});
  String initial(String uid){const fallback={'u2':'C','u1':'D','u3':'A','u4':'J'};final u=data.users.where((x)=>x.id==uid);return u.isEmpty?(fallback[uid]??'?'):u.first.name.substring(0,1).toUpperCase();}
  @override Widget build(BuildContext context){
    final first=DateTime(data.month.year,data.month.month,1),offset=first.weekday-1,days=DateTime(data.month.year,data.month.month+1,0).day;
    final order=data.users.isEmpty?const ['u2','u1','u3','u4']:data.users.map((u)=>u.id).toList();
    return GridView.builder(padding:const EdgeInsets.all(6),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:.57,crossAxisSpacing:3,mainAxisSpacing:3),itemCount:offset+days,itemBuilder:(context,i){
      if(i<offset)return const SizedBox.shrink();final day=i-offset+1,date=DateTime(data.month.year,data.month.month,day),key='${date.year}-${date.month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}',holiday=data.holidays[key];
      return Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:holiday!=null?const Color(0xFF25151B):const Color(0xFF101823),borderRadius:BorderRadius.circular(8),border:holiday!=null?Border.all(color:const Color(0xFF8B3349)):null),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text('$day',style:const TextStyle(fontWeight:FontWeight.w800)),if(holiday!=null)const Padding(padding:EdgeInsets.only(left:2),child:Text('•',style:TextStyle(color:Colors.redAccent)))]),const SizedBox(height:2),
        for(final uid in order)Expanded(child:Container(width:double.infinity,margin:const EdgeInsets.symmetric(vertical:1),padding:const EdgeInsets.symmetric(horizontal:2),decoration:BoxDecoration(color:data.serviceColor(data.assignments['$uid|$key']),borderRadius:BorderRadius.circular(4)),child:FittedBox(fit:BoxFit.scaleDown,child:Text('${initial(uid)} ${data.assignments['$uid|$key']??'—'}',style:const TextStyle(fontWeight:FontWeight.w800))))),
      ]));
    });
  }
}
