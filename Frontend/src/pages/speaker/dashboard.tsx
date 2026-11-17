import { useAuth } from "@/context/auth-context";
import { CalendarDays, UserRound, Clock3 } from "lucide-react";

export function SpeakerDashboard() {
  const { user } = useAuth();
  const stats = [
    { label: "My sessions", value: "0", icon: CalendarDays },
    { label: "Profile completeness", value: "0%", icon: UserRound },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Speaker Dashboard</h1>
        <p className="text-sm text-muted-foreground">
          View your assigned sessions and manage your speaker profile. Welcome back, {user?.name}.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {stats.map(({ label, value, icon: Icon }) => (
          <div key={label} className="rounded-xl border border-border bg-card p-5">
            <Icon className="h-4 w-4 text-[hsl(var(--primary))]" />
            <div className="mt-5 flex items-baseline gap-1">
              <span className="display-font text-2xl font-bold">{value}</span>
            </div>
            <div className="mt-1 text-sm text-muted-foreground">{label}</div>
          </div>
        ))}
      </div>

      <div className="rounded-xl border border-border bg-card p-6">
        <h2 className="text-lg font-bold">My sessions</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          No sessions assigned yet. Check back later or contact an organiser.
        </p>
      </div>
    </div>
  );
}