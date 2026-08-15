import * as React from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";

export interface ListRowProps {
  title: React.ReactNode;
  meta?: React.ReactNode;
  trailing?: React.ReactNode;
  href?: string;
  onClick?: () => void;
  className?: string;
}

export function ListRow({ title, meta, trailing, href, onClick, className }: ListRowProps) {
  const inner = (
    <>
      <div className="flex items-center justify-between gap-3 min-w-0">
        <div className="min-w-0">
          <div className="text-sm font-semibold text-[var(--color-ink)] truncate">{title}</div>
          {meta && <div className="text-sm text-[var(--color-ink-variant)]">{meta}</div>}
        </div>
        {trailing && <div className="shrink-0 flex items-center gap-2">{trailing}</div>}
      </div>
    </>
  );

  const classes = cn(
    "w-full px-7 py-3.5 border-b border-[var(--color-outline-subtle)] last:border-b-0",
    "transition-colors duration-[var(--duration-fast)]",
    href || onClick ? "hover:bg-[var(--color-primary-light)] cursor-pointer" : "",
    className,
  );

  if (href) {
    return (
      <Link href={href} className={classes} onClick={onClick}>
        {inner}
      </Link>
    );
  }
  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={classes + " text-left"}>
        {inner}
      </button>
    );
  }
  return <div className={classes}>{inner}</div>;
}
