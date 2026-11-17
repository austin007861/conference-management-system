import { useState } from "react";
import { Link, useLocation } from "wouter";
import { Button } from "@/components/ui/button";
import { ArrowRight, Mail, Lock } from "lucide-react";

export function SignupPage() {
  const [, setLocation] = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    setIsLoading(true);
    try {
      const response = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        throw new Error((body as { message?: string })?.message || "Signup failed");
      }

      setLocation("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Signup failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="auth-page min-h-[100dvh] w-full bg-background relative overflow-hidden">
      <div className="relative z-10 flex w-full items-center justify-center px-5 min-h-[100dvh]">
        <div className="flex flex-col items-center justify-center p-6 lg:w-1/2 lg:p-16 min-h-[560px]">
          <div className="w-full max-w-md">
            <div className="text-center mb-10">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[hsl(var(--primary))] text-[hsl(var(--primary-foreground))] mx-auto mb-4 shadow-lg shadow-[hsl(var(--primary))/0.35]">
                <Lock className="h-6 w-6 fill-current" />
              </div>
              <h1 className="display-font text-3xl font-bold tracking-tight text-foreground mb-2">Create an account</h1>
              <p className="text-[hsl(var(--muted-foreground))] text-sm">
                Join your conference workspace to get started.
              </p>
            </div>

            {error && (
              <div className="mb-6 rounded-lg border border-[hsl(var(--destructive)/.3)] bg-[hsl(var(--destructive)/.08)] p-4 text-sm text-[hsl(var(--destructive))] shadow-sm">
                {error}
              </div>
            )}

            <form className="grid gap-5" onSubmit={handleSubmit}>
              <div className="grid gap-2">
                <Mail className="text-muted-foreground text-sm" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@organisation.org"
                  required
                  autoComplete="email"
                  className="h-11 w-full rounded-xl border border-input bg-background px-4 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/15 pl-10 transition-all"
                  data-testid="input-signup-email"
                />
              </div>
              <div className="grid gap-2">
                <Lock className="text-muted-foreground text-sm" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  required
                  autoComplete="new-password"
                  className="h-11 w-full rounded-xl border border-input bg-background px-4 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/15 pl-10 transition-all"
                  data-testid="input-signup-password"
                />
              </div>
              <Button
                type="submit"
                className="h-11 w-full font-semibold"
                disabled={isLoading}
                data-testid="button-submit-signup"
              >
                {isLoading ? "Creating account…" : "Create account"}
                <ArrowRight className="h-4 w-4" />
              </Button>
            </form>

            <p className="mt-10 text-center text-sm text-[hsl(var(--muted-foreground))]">
              Already have an account?{" "}
              <Link href="/login" className="font-bold text-[hsl(var(--primary))] hover:underline" data-testid="link-signup-login">
                Sign in
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
