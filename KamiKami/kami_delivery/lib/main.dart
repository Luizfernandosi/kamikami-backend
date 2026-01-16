import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import 'firebase_options.dart'; // Certifique-se que este arquivo existe

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KamiKami Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final corLaranja = Colors.orange;

  bool carregando = true;

  List<Map<String, dynamic>> produtos = [];
  List<String> categorias = [];

  Map<String, Map<String, dynamic>> carrinhoMap = {};

  User? usuario;

  final cpfC = TextEditingController();
  final nomeC = TextEditingController();
  final telC = TextEditingController();
  final emailC = TextEditingController();
  final senhaC = TextEditingController();

  @override
  void initState() {
    super.initState();
    usuario = FirebaseAuth.instance.currentUser;
    buscarProdutosFirebase();
  }

  Future<void> buscarProdutosFirebase() async {
    final snap = await FirebaseFirestore.instance.collection('produtos').get();
    List<Map<String, dynamic>> lista = [];
    Set<String> cats = {};

    for (var doc in snap.docs) {
      final d = doc.data();
      if (d['ativo'] == true) {
        lista.add({
          'id': doc.id,
          'nome': d['nome'],
          'preco': (d['preco'] as num).toDouble(),
          'emoji': d['emoji'] ?? "🥡",
          'categoria': d['categoria'] ?? "Outros",
        });
        cats.add(d['categoria'] ?? "Outros");
      }
    }

    if (!mounted) return;
    setState(() {
      produtos = lista;
      categorias = cats.toList();
      carregando = false;
    });
  }

  void mostrarJanelaUsuario() {
    int aba = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => setDialog(() => aba = 0),
                child: Text("LOGIN",
                    style: TextStyle(
                        color: aba == 0 ? corLaranja : Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: () => setDialog(() => aba = 1),
                child: Text("CADASTRO",
                    style: TextStyle(
                        color: aba == 1 ? corLaranja : Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (aba == 1) ...[
                TextField(controller: cpfC, decoration: const InputDecoration(labelText: "CPF")),
                TextField(controller: nomeC, decoration: const InputDecoration(labelText: "Nome Completo")),
                TextField(controller: telC, decoration: const InputDecoration(labelText: "Telefone")),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email")),
              ],
              TextField(controller: senhaC, decoration: const InputDecoration(labelText: "Senha"), obscureText: true),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                try {
                  if (aba == 0) {
                    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: emailC.text,
                      password: senhaC.text,
                    );
                    if (!mounted) return;
                    setState(() => usuario = cred.user);
                  } else {
                    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: emailC.text,
                      password: senhaC.text,
                    );

                    await FirebaseFirestore.instance
                        .collection('clientes')
                        .doc(cred.user!.uid)
                        .set({
                      'cpf': cpfC.text,
                      'nome': nomeC.text,
                      'telefone': telC.text,
                      'email': emailC.text,
                      'criado_em': Timestamp.now(),
                    });

                    if (!mounted) return;
                    setState(() => usuario = cred.user);
                  }

                  if (!mounted) return;
                  Navigator.pop(ctx);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Erro no login/cadastro")),
                  );
                }
              },
              child: Text(aba == 0 ? "ENTRAR" : "CRIAR CONTA"),
            )
          ],
        ),
      ),
    );
  }

  bool validarCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11) return false;
    if (cpf.split('').every((c) => c == cpf[0])) return false;
    return true;
  }

  Future<void> realizarCheckout() async {
    if (usuario == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faça login antes de finalizar o pedido")),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('clientes').doc(usuario!.uid).get();
    final clienteData = doc.data()!;

    if (!validarCPF(clienteData['cpf'])) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CPF inválido")),
      );
      return;
    }

    final pedido = {
      "itens": carrinhoMap.entries.map((e) => {
        "nome": e.value['nome'],
        "preco": e.value['preco'],
        "quantidade": e.value['qtd']
      }).toList(),
      "cliente": {
        "nome": clienteData['nome'],
        "cpf": clienteData['cpf'],
        "telefone": clienteData['telefone'],
        "email": clienteData['email']
      },
      "total": carrinhoMap.values.fold(0.0, (prev, item) => prev + (item['preco'] * item['qtd']))
    };

    try {
      final url = Uri.parse("http://SEU_BACKEND_URL/checkout/pix"); // <== coloque a URL do backend
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(pedido),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final qrBase64 = data['qr_code_base64'];
        final qrBytes = base64Decode(qrBase64);
        final qrCodeText = data['id'].toString();

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Pagamento PIX"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(Uint8List.fromList(qrBytes)),
                const SizedBox(height: 10),
                SelectableText("Código PIX: $qrCodeText"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qrCodeText));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Código PIX copiado!")),
                  );
                },
                child: const Text("Copiar Código"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Fechar"),
              )
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao gerar pagamento")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao conectar com o backend")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = carrinhoMap.values.fold(
      0.0, 
      (prev, item) => prev + (item['preco'] * item['qtd']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("KAMI KAMI YAKISSOBA"),
        actions: [
          IconButton(
            icon: Icon(usuario != null ? Icons.person : Icons.person_outline),
            onPressed: mostrarJanelaUsuario,
          )
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (var cat in categorias) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(cat.toUpperCase(),
                        style: TextStyle(
                            color: corLaranja,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...produtos.where((p) => p['categoria'] == cat).map((p) {
                    final id = p['id'];
                    return ListTile(
                      leading: Text(p['emoji'], style: const TextStyle(fontSize: 28)),
                      title: Text(p['nome']),
                      subtitle: Text("R\$ ${p['preco'].toStringAsFixed(2)}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.orange),
                        onPressed: () {
                          setState(() {
                            if (carrinhoMap.containsKey(id)) {
                              carrinhoMap[id]!['qtd']++;
                            } else {
                              carrinhoMap[id] = {
                                'nome': p['nome'],
                                'preco': p['preco'],
                                'qtd': 1
                              };
                            }
                          });
                        },
                      ),
                    );
                  }),
                ]
              ],
            ),
      bottomNavigationBar: carrinhoMap.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: realizarCheckout,
                child: Text("TOTAL: R\$ ${total.toStringAsFixed(2)}"),
              ),
            ),
    );
  }
}
