# opencode con los modelos locales de ollama (servicio del sistema en sokix-wsl,
# ver nixos/hosts/wsl/ia.nix en el repo nixos). opencode solo ofrece los modelos
# listados en `models`: tras `ollama pull <modelo>`, añádelo ahí con su nombre exacto,
# p. ej. "qwen3-coder:30b".name = "Qwen3 Coder 30B"; y, si quieres que sea el de
# por defecto, model = "ollama/qwen3-coder:30b"; en settings.
{ ... }:

{
  programs.opencode = {
    enable = true;
    settings.provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = "http://localhost:11434/v1";
      models = {
        # GGUF de sharunkrish/whiterabbitneo-2.5-qwen-2.5-coder-7b-awq (AWQ no va en
        # ollama). Alias: `ollama create whiterabbitneo:7b -f whiterabbitneo.Modelfile`: num_ctx 16384 + plantilla Qwen2.5
        # con tools (la del GGUF no los soporta y opencode los necesita).
        "whiterabbitneo:7b".name = "WhiteRabbitNeo 2.5 Qwen2.5 Coder 7B";
      };
    };
  };
}
