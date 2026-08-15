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

/** Data-dense list row: title + meta left, status chip / numeric value right. */
export function ListRow({ title, meta, trailing, href, onClick, className }: ListRowProps) {
  const inner = (
    <>
      <div className="flex items-center justify-between gap-md min-w-0">
        <div className="min-w-0">
          <div className="text-sm font-display font-semibold text-on-surface truncate">{title}</div>
          {meta && <div className="text-sm text-on-surface-variant">{meta}</div>}
        </div>
        {trailing && <div className="shrink-0 flex items-center gap-sm">{trailing}</div>}
      </div>
    </>
  );

  const classes = cn(
    "w-full px-lg py-md border-b border-outline last:border-b-0",
    "transition-colors duration-fast",
    href || onClick ? "hover:bg-primary/5 cursor-pointer" : "",
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