"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
  /**
   * Whether Escape and a backdrop click close it. False for a dialog that has
   * to be answered — an acknowledgement dismissed by a stray click outside has
   * not been given.
   */
  dismissible?: boolean;
}

export function Dialog({ open, onClose, title, children, footer, className, dismissible = true }: DialogProps) {
  const panelRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && dismissible) onClose();
    };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open, onClose, dismissible]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center p-7"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        className="absolute inset-0 bg-black/50 animate-[fadeIn_200ms_ease-out]"
        onClick={dismissible ? onClose : undefined}
        aria-hidden="true"
      />
      <div
        ref={panelRef}
        className={cn(
          "relative w-full max-w-md bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-lg)] shadow-[var(--shadow-xl)] p-7",
          "max-h-[calc(100vh-4rem)] overflow-y-auto",
          "animate-[popIn_250ms_cubic-bezier(0.34,1.56,0.64,1)]",
          className,
        )}
      >
        {title && <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-5">{title}</h2>}
        <div className="text-[var(--color-ink)]">{children}</div>
        {footer && <div className="mt-6 flex justify-end gap-3">{footer}</div>}
      </div>
    </div>
  );
}
