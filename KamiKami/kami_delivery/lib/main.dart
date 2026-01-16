import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MaterialApp(home: AppCliente(), debugShowCheckedModeBanner: false));

class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override State<AppCliente> createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  final Color corLaranja = const Color(0xFFFF944D);
  final Color corPreta = const Color(0xFF1A1A1A);
  final String projetoId = "kamikami-af5fe"; 
  final String urlBase = "https://kamikami-backend.onrender.com"; 

  List produtos = [];
  List categorias = [];
  bool carregando = true;
  Map<String, Map<String, dynamic>> carrinhoMap = {};
  double frete = 7.00;

  // Controllers Endereço
  TextEditingController cepC = TextEditingController();
  TextEditingController ruaC = TextEditingController();
  TextEditingController numC = TextEditingController();
  TextEditingController refC = TextEditingController();
  TextEditingController cupomC = TextEditingController();
  
  // Controllers Login/Cadastro
  TextEditingController nomeC = TextEditingController();
  TextEditingController telC = TextEditingController();
  TextEditingController senhaC = TextEditingController();
  Map? usuarioLogado;

  @override
  void initState() { super.initState(); buscarDadosFirebase(); }

  // BUSCA CEP AUTOMÁTICA E TRAVA CAMPOS
  Future<void> buscarCEP(String cep, Function setModalState) async {
    if (cep.length == 8) {
      final res = await http.get(Uri.parse("https://viacep.com.br/ws/$cep/json/"));
      if (res.statusCode == 200) {
        final dados = json.decode(res.body);
        if (dados['logradouro'] != null) {
          setModalState(() {
            ruaC.text = "${dados['logradouro']}, ${dados['bairro']} - ${dados['localidade']}";
          });
        }
      }
    }
  }

  Future<void> buscarDadosFirebase() async {
    try {
      final url = Uri.parse("https://firestore.googleapis.com/v1/projects/$projetoId/databases/(default)/documents/produtos");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final dados = json.decode(res.body);
        List listaTemp = [];
        Set categoriasTemp = {};
        if (dados['documents'] != null) {
          for (var doc in dados['documents']) {
            var campos = doc['fields'];
            if (campos['ativo']?['booleanValue'] ?? true) {
              String cat = campos['categoria']?['stringValue'] ?? "Cardápio";
              listaTemp.add({
                "nome": campos['nome']?['stringValue'] ?? "Sem Nome",
                "preco": double.parse(campos['preco']?['doubleValue']?.toString() ?? campos['preco']?['integerValue'] ?? "0"),
                "emoji": campos['emoji']?['stringValue'] ?? "🥡",
                "desc": campos['desc']?['stringValue'] ?? "",
                "categoria": cat,
              });
              categoriasTemp.add(cat);
            }
          }
        }
        setState(() { produtos = listaTemp; categorias = categoriasTemp.toList(); carregando = false; });
      }
    } catch (e) { setState(() { carregando = false; }); }
  }

  // MERCADO PAGO
  Future<void> pagarMercadoPago(double total) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Iniciando pagamento...")));
    try {
      final res = await http.post(Uri.parse('$urlBase/criar_pagamento'), 
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: json.encode({
          "titulo": "Pedido KamiKami Yakissoba",
          "valor": total,
          "email": usuarioLogado?['email'] ?? "cliente@email.com"
        })).timeout(const Duration(seconds: 30));
        
      final d = json.decode(res.body);
      if (d['link'] != null) {
        await launchUrl(Uri.parse(d['link']), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao conectar ao Mercado Pago. Tente novamente.")));
    }
  }

  // JANELA DE LOGIN E CADASTRO
  void mostrarJanelaUsuario() {
    int aba = 0; 
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(onTap: () => setDialogState(() => aba = 0), child: Text("LOGIN", style: TextStyle(color: aba == 0 ? corLaranja : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
              GestureDetector(onTap: () => setDialogState(() => aba = 1), child: Text("CADASTRO", style: TextStyle(color: aba == 1 ? corLaranja : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (aba == 1) TextField(controller: nomeC, decoration: const InputDecoration(labelText: "Nome Completo")),
                TextField(controller: telC, decoration: const InputDecoration(labelText: "WhatsApp (DDD + Número)"), keyboardType: TextInputType.phone),
                TextField(controller: senhaC, decoration: const InputDecoration(labelText: "Senha"), obscureText: true),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corLaranja, minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                if (telC.text.isEmpty || senhaC.text.isEmpty || (aba == 1 && nomeC.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!")));
                  return;
                }
                try {
                  String rota = aba == 0 ? "/login_usuario" : "/registrar_usuario";
                  Map corpo = aba == 0 
                    ? {"telefone": telC.text, "senha": senhaC.text} 
                    : {"nome": nomeC.text, "telefone": telC.text, "senha": senhaC.text};

                  final res = await http.post(
                    Uri.parse("$urlBase$rota"), 
                    headers: {"Content-Type": "application/json", "Accept": "application/json"},
                    body: json.encode(corpo)
                  ).timeout(const Duration(seconds: 30));

                  final d = json.decode(res.body);
                  if (d['status'] == 'sucesso') {
                    setState(() { usuarioLogado = d['usuario']; });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bem-vindo, ${d['usuario']['nome']}!")));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['mensagem'] ?? "Erro na operação")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Servidor demorou a responder. Tente novamente.")));
                }
              }, 
              child: Text(aba == 0 ? "ENTRAR" : "CRIAR CONTA", style: const TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void abrirCheckout(double totalFinal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.9,
          child: ListView(
            children: [
              const Center(child: Text("REVISÃO E PAGAMENTO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const Divider(),
              const Text("📦 ITENS NO PEDIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ...carrinhoMap.entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                    setState(() { if (carrinhoMap[e.key]!['qtd'] > 1) { carrinhoMap[e.key]!['qtd']--; } else { carrinhoMap.remove(e.key); } });
                    setModalState(() {});
                  }),
                  Text("${e.value['qtd']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () {
                    setState(() { carrinhoMap[e.key]!['qtd']++; });
                    setModalState(() {});
                  }),
                ]),
              )).toList(),
              const Divider(),
              const Text("📍 ENDEREÇO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              TextField(controller: cepC, decoration: const InputDecoration(labelText: "CEP"), onChanged: (v) => buscarCEP(v, setModalState), keyboardType: TextInputType.number),
              TextField(controller: ruaC, enabled: false, decoration: const InputDecoration(labelText: "Endereço Automático")),
              TextField(controller: numC, decoration: const InputDecoration(labelText: "Número/Apto")),
              TextField(controller: refC, decoration: const InputDecoration(labelText: "Referência")),
              const SizedBox(height: 15),
              const Text("🎟️ CUPOM", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              TextField(controller: cupomC, decoration: const InputDecoration(hintText: "Digite seu código")),
              const Divider(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${(totalFinal - frete).toStringAsFixed(2)}")]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Frete:", style: TextStyle(color: Colors.red)), Text("R\$ ${frete.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red))]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("TOTAL:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("R\$ ${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
                onPressed: () {
                  if (usuarioLogado == null) {
                    Navigator.pop(ctx);
                    mostrarJanelaUsuario();
                  } else if (cepC.text.isEmpty || numC.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha CEP e Número!")));
                  } else {
                    pagarMercadoPago(totalFinal);
                  }
                },
                child: Text(usuarioLogado == null ? "LOGIN PARA FINALIZAR" : "PAGAR AGORA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalItens = carrinhoMap.values.fold(0.0, (sum, item) => sum + (item['preco'] * item['qtd']));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPreta,
        centerTitle: true,
        title: const Text("KAMI KAMI YAKISSOBA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(usuarioLogado != null ? Icons.person : Icons.person_outline, color: Colors.white, size: 28),
            onPressed: mostrarJanelaUsuario,
          )
        ],
      ),
      body: carregando ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), color: corLaranja, child: const Text("MENU COMPLETO", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(child: ListView(children: [
            for (var cat in categorias) ...[
              Padding(padding: const EdgeInsets.all(15), child: Text(cat.toUpperCase(), style: TextStyle(color: corLaranja, fontWeight: FontWeight.bold, fontSize: 18))),
              ...produtos.where((p) => p['categoria'] == cat).map((p) => ListTile(
                leading: Text(p['emoji'], style: const TextStyle(fontSize: 30)),
                title: Text(p['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("R\$ ${p['preco'].toStringAsFixed(2)}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (carrinhoMap.containsKey(p['nome'])) ...[
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() {
                        if (carrinhoMap[p['nome']]!['qtd'] > 1) { carrinhoMap[p['nome']]!['qtd']--; } 
                        else { carrinhoMap.remove(p['nome']); }
                      })),
                      Text("${carrinhoMap[p['nome']]!['qtd']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 30), onPressed: () => setState(() {
                      if (carrinhoMap.containsKey(p['nome'])) { carrinhoMap[p['nome']]!['qtd']++; } 
                      else { carrinhoMap[p['nome']] = {'preco': p['preco'], 'qtd': 1}; }
                    })),
                  ],
                ),
              )),
            ],
          ])),
          if (carrinhoMap.isNotEmpty) 
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
                onPressed: () => abrirCheckout(totalItens + frete),
                child: Text("REVISAR PEDIDO - R\$ ${(totalItens + frete).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}