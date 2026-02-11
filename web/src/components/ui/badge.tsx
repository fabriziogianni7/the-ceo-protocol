import * as React from "react";

const badgeVariants = {
  default:
    "bg-[var(--primary)] text-[var(--primary-foreground)]",
  secondary:
    "bg-[var(--secondary)] text-[var(--secondary-foreground)]",
  accent:
    "bg-[var(--accent)] text-[var(--accent-foreground)]",
  destructive:
    "bg-[var(--destructive)] text-[var(--destructive-foreground)]",
  outline: "border border-[var(--border)]",
};

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: keyof typeof badgeVariants;
}

const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className = "", variant = "default", ...props }, ref) => (
    <span
      ref={ref}
      className={`inline-flex items-center rounded-[var(--radius)] px-2.5 py-0.5 text-xs font-medium ${badgeVariants[variant]} ${className}`}
      {...props}
    />
  )
);
Badge.displayName = "Badge";

export { Badge, badgeVariants };
