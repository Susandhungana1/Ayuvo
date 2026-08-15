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
}

/**
 * Modal dialog: overlay, `lg` radius panel, elevation token, Escape to close,
 * body scroll locked while open. Used for destructive confirmations.
 */
export function Dialog({ open, onClose, title, children, footer, className }: DialogProps) {
  const panelRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center p-lg"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        className="absolute inset-0 bg-black/50 anim-fade-in"
        onClick={onClose}
        aria-hidden="true"
      />
      <div
        ref={panelRef}
        className={cn(
          "relative w-full max-w-md bg-surface-card rounded-lg shadow-pop p-lg anim-pop-in",
          "max-h-[calc(100vh-4rem)] overflow-y-auto",
          className,
        )}
      >
        {title && <h2 className="text-xl font-display font-semibold text-on-surface mb-lg">{title}</h2>}
        <div className="text-on-surface">{children}</div>
        {footer && <div className="mt-xl flex justify-end gap-sm">{footer}</div>}
      </div>
    </div>
  );
}