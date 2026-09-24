import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget{
  final VoidCallback onSignedIn; const LoginScreen({super.key,required this.onSignedIn});
  @override State<LoginScreen> createState()=>_LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen>{
  final email=TextEditingController(),password=TextEditingController();bool busy=false;String? error;
  Future<void> login()async{
    setState(()=>busy=true);
    try{await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);widget.onSignedIn();}
    on AuthException catch(e){setState(()=>error=e.message);}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:420),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.calendar_month_rounded,size:64),const SizedBox(height:18),
      const Text('TURNEO',textAlign:TextAlign.center,style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),const Text('Acceso al cuadrante',textAlign:TextAlign.center),
      const SizedBox(height:28),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
      const SizedBox(height:12),TextField(controller:password,obscureText:true,onSubmitted:(_)=>login(),decoration:const InputDecoration(labelText:'Contraseña',border:OutlineInputBorder())),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.redAccent))],
      const SizedBox(height:16),FilledButton(onPressed:busy?null:login,child:Padding(padding:const EdgeInsets.all(14),child:Text(busy?'ENTRANDO…':'ENTRAR'))),
    ]))))));
}
