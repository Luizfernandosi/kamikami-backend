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
  final String urlBase = "https://kamikami-backend.onrender.com"; // Seu Render

  List produtos = [];
  List categorias = [];
  bool carregando = true;
  Map<String, Map<String, dynamic>> carrinhoMap = {};
  double frete = 7.00;

  // CONTROLLERS E ESTADOS
  TextEditingController cepC = TextEditingController();
  TextEditingController ruaC = TextEditingController();
  TextEditingController numC = TextEditingController();
  TextEditingController refC = TextEditingController();
  TextEditingController cupomC = TextEditingController();
  
  // Login
  TextEditingController emailC = TextEditingController();
  TextEditingController senhaC = TextEditingController();
  Map? usuarioLogado;

  @override
  void initState() { super.initState(); buscarDadosFirebase(); }

  // 1. BUSCA DE DADOS
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

  // 2. FUNÇÃO DE LOGIN/CADASTRO (Simples e Eficaz via Backend)
  void mostrarJanelaLogin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Entrar na KamiKami"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailC, decoration: const InputDecoration(labelText: "E-mail ou Telefone")),
            TextField(controller: senhaC, decoration: const InputDecoration(labelText: "Senha"), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Sair")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corLaranja),
            onPressed: () async {
              // Conecta com a rota de login que criamos no seu main.py
              final res = await http.post(Uri.parse('$urlBase/login_usuario'), 
                headers: {"Content-Type": "application/json"},
                body: json.encode({"telefone": emailC.text, "senha": senhaC.text}));
              
              final d = json.decode(res.body);
              if (d['status'] == 'sucesso') {
                setState(() { usuarioLogado = d['usuario']; });
                Navigator.pop(ctx);
              }
            }, 
            child: const Text("ENTRAR", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  // 3. MERCADO PAGO (Abre link de pagamento)
  Future<void> pagarMercadoPago(double total) async {
    // Aqui chamamos seu backend para gerar o link do MP
    final res = await http.post(Uri.parse('$urlBase/criar_pagamento'), 
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "titulo": "Pedido KamiKami",
        "valor": total,
        "email": usuarioLogado?['email'] ?? "cliente@email.com"
      }));
    
    final d = json.decode(res.body);
    if (d['link'] != null) {
      launchUrl(Uri.parse(d['link']), mode: LaunchMode.externalApplication);
    }
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
              const Center(child: Text("FINALIZAR PEDIDO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const Divider(),
              const Text("📦 ITENS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ...carrinhoMap.entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                    setState(() { if (carrinhoMap[e.key]!['qtd'] > 1) { carrinhoMap[e.key]!['qtd']--; } else { carrinhoMap.remove(e.key); } });
                    setModalState(() {});
                  }),
                  Text("${e.value['qtd']}"),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () {
                    setState(() { carrinhoMap[e.key]!['qtd']++; });
                    setModalState(() {});
                  }),
                ]),
              )).toList(),
              const Divider(),
              const Text("📍 ENDEREÇO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              TextField(controller: cepC, decoration: const InputDecoration(labelText: "CEP")),
              TextField(controller: ruaC, decoration: const InputDecoration(labelText: "Rua/Bairro")),
              TextField(controller: numC, decoration: const InputDecoration(labelText: "Número/Apto")),
              const SizedBox(height: 15),
              const Text("🎟️ CUPOM", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              TextField(controller: cupomC, decoration: const InputDecoration(hintText: "Possui cupom?")),
              const Divider(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Produtos:"), Text("R\$ ${(totalFinal - frete).toStringAsFixed(2)}")]),
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
                    mostrarJanelaLogin();
                  } else {
                    pagarMercadoPago(totalFinal);
                  }
                },
                child: Text(usuarioLogado == null ? "FAZER LOGIN PARA PEDIR" : "PAGAR COM MERCADO PAGO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            onPressed: mostrarJanelaLogin,
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
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                        setState(() { if (carrinhoMap[p['nome']]!['qtd'] > 1) { carrinhoMap[p['nome']]!['qtd']--; } else { carrinhoMap.remove(p['nome']); } });
                      }),
                      Text("${carrinhoMap[p['nome']]!['qtd']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 30), onPressed: () {
                      setState(() {
                        if (carrinhoMap.containsKey(p['nome'])) { carrinhoMap[p['nome']]!['qtd']++; } 
                        else { carrinhoMap[p['nome']] = {'preco': p['preco'], 'qtd': 1}; }
                      });
                    }),
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