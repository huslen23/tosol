import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

// The browser manages HttpOnly registration cookies across API requests.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
