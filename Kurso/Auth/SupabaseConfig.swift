import Foundation

/// Coordonnees du projet Supabase.
///
/// La cle `anon` est publique par conception : elle part dans chaque client et
/// n'ouvre que ce que les regles RLS autorisent. La cle `service_role`, elle,
/// ne doit jamais approcher ce fichier — elle ignore RLS.
enum SupabaseConfig {
    static let url = URL(string: "https://deflypgzjbtunupjzhcn.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlZmx5cGd6amJ0dW51cGp6aGNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwMzMyMjcsImV4cCI6MjA4OTYwOTIyN30.VoN8TC9y8Au9kHWrleGvX1cDm_CDHlMSPtXdS_m-2tg"
}
