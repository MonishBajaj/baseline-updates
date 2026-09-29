import { Card, CardContent } from '@/components/ui/Card';
import { withItalicEColi } from '@/lib/eColi';
import { withBase } from '@/lib/publicUrl';

const SCOPE_ITEMS = [
  { label: 'Crop', value: 'Onion' },
  { label: 'Production stage', value: 'Preharvest' },
  { label: 'Region', value: 'Southeastern U.S.' },
  { label: 'Indicator organism', value: 'Generic E. coli' },
  { label: 'Contamination sources', value: 'Irrigation water and wildlife' },
  { label: 'Primary outputs', value: 'Soil contamination and onion surface contamination at harvest' },
] as const;

const INTRO_IMAGES = [
  {
    src: withBase('img/Model Field Structure.png'),
    alt: 'Model field structure',
  },
  {
    src: withBase('img/Onion Production Calendar.png'),
    alt: 'Onion production calendar',
  },
] as const;

export function IntroductionPage() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">
          Food Safety Risk Assessment Tool for Vidalia Onion Production Fields across the Southeastern U. S.
        </h2>
      </div>

      <Card>
        <CardContent>
          <h3 className="text-lg font-semibold text-uga-black">About the Model</h3>
          <div className="mt-1.5 space-y-3 text-lg leading-relaxed text-uga-dark-gray">
            <p>
              This interactive model evaluates how irrigation water, wildlife intrusion, field conditions, and
              production practices may influence <em className="italic">E. coli</em> contamination during onion production
              in the Southeastern U.S.
            </p>
            <p>
              Use the dashboard to explore baseline conditions, test alternative scenarios, and identify factors that
              most strongly influence contamination at harvest.
            </p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <h3 className="text-lg font-semibold text-uga-black">Model Scope</h3>
          <dl className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {SCOPE_ITEMS.map((item) => (
              <div
                key={item.label}
                className="rounded-md border border-uga-card-border bg-uga-light-gray px-3.5 py-3"
              >
                <dt className="text-base font-medium text-uga-dark-gray">{item.label}</dt>
                <dd className="mt-0.5 text-lg font-semibold leading-snug text-uga-black">{withItalicEColi(item.value)}</dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-lg leading-relaxed text-uga-dark-gray">
            The model integrates published literature, environmental monitoring data, field information, and expert
            knowledge to simulate contamination pathways during onion production.
          </p>
        </CardContent>
      </Card>

      <div className="rounded-md border border-l-4 border-uga-card-border border-l-uga-red bg-uga-red/5 p-4">
        <h3 className="text-lg font-semibold text-uga-red">{withItalicEColi('About Generic E. coli')}</h3>
        <p className="mt-1.5 text-lg leading-relaxed text-uga-dark-gray">
          Generic <em className="italic">E. coli</em> is used as an indicator of fecal contamination and environmental
          sanitary conditions. It is
          not interpreted as a direct measure of the presence or concentration of specific foodborne pathogens. The
          indicator is used to evaluate conditions that may be relevant to enteric pathogen contamination, rather than
          to predict a specific pathogen directly.
        </p>
      </div>

      <Card className="overflow-hidden">
        <div className="flex flex-col gap-6 p-4 sm:p-6">
          <h3 className="text-lg font-semibold text-uga-black">Model Field Structures</h3>
          <img
            src={INTRO_IMAGES[0].src}
            alt={INTRO_IMAGES[0].alt}
            className="h-auto w-full rounded-md border border-uga-card-border object-contain"
          />
          <h3 className="text-lg font-semibold text-uga-black">Onion Production Calendar</h3>
          <img
            src={INTRO_IMAGES[1].src}
            alt={INTRO_IMAGES[1].alt}
            className="h-auto w-full rounded-md border border-uga-card-border object-contain"
          />
        </div>
      </Card>

      <Card>
        <CardContent>
          <h3 className="text-lg font-semibold text-uga-black">Model Limitations</h3>
          <p className="mt-1.5 text-lg leading-relaxed text-uga-dark-gray">
            This dashboard is intended for research, education, and decision support. Model outputs are estimates based
            on available data, published literature, expert knowledge, and model assumptions. Results should not be
            interpreted as guarantees of contamination or safety and do not replace regulatory requirements, field
            assessments, or professional food safety guidance.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
