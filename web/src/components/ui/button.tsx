import * as React from "react";

const buttonVariants = {
  default:
    "bg-[var(--primary)] text-[var(--primary-foreground)] hover:opacity-90",
  secondary:
    "bg-[var(--secondary)] text-[var(--secondary-foreground)] hover:opacity-90",
  accent:
    "bg-[var(--accent)] text-[var(--accent-foreground)] hover:opacity-90",
  destructive:
    "bg-[var(--destructive)] text-[var(--destructive-foreground)] hover:opacity-90",
  outline:
    "border border-[var(--border)] bg-transparent hover:bg-[var(--muted)]",
  ghost: "hover:bg-[var(--muted)]",
  link: "text-[var(--primary)] underline-offset-4 hover:underline",
};

const buttonSizes = {
  sm: "h-8 px-3 text-xs",
  md: "h-10 px-4 text-sm",
  lg: "h-12 px-6 text-base",
};

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: keyof typeof buttonVariants;
  size?: keyof typeof buttonSizes;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className = "", variant = "default", size = "md", ...props }, ref) => (
    <button
      ref={ref}
      className={`inline-flex items-center justify-center rounded-[var(--radius)] font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)] focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 ${buttonVariants[variant]} ${buttonSizes[size]} ${className}`}
      {...props}
    />
  )
);
Button.displayName = "Button";

export { Button, buttonVariants, buttonSizes };
