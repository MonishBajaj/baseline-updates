export function Header() {
  return (
    <header className="fixed top-0 right-0 left-0 z-50 grid h-16 grid-cols-3 items-center bg-uga-red px-6 shadow-md">
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded bg-white">
          <span className="text-base font-black text-uga-red">UGA</span>
        </div>
        <div>
          <p className="text-lg leading-tight font-bold text-white">FMRA Lab</p>
          <p className="text-base text-white/70">Food Microbiology &amp; Risk Assessment</p>
        </div>
      </div>

      <div className="hidden text-center sm:block">
        <h1 className="text-xl font-bold tracking-wide text-white">Onion E. coli Risk Dashboard</h1>
        <p className="text-base text-white/70">Preharvest system model</p>
      </div>
    </header>
  );
}
